package com.example.security_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbManager
import android.media.ToneGenerator
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import java.io.BufferedReader
import java.io.InputStreamReader

class AdbDetectionService : Service() {
    private lateinit var handler: Handler
    private lateinit var usbReceiver: BroadcastReceiver
    private lateinit var vibrator: Vibrator
    private lateinit var toneGenerator: ToneGenerator
    private var isAdbConnected = false
    private var isReceiverRegistered = false
    
    private lateinit var vibrateRunnable: Runnable
    private lateinit var beepRunnable: Runnable
    private lateinit var adbCheckRunnable: Runnable

    companion object {
        private const val CHANNEL_ID = "adb_detection_channel"
        private const val NOTIFICATION_ID = 2
    }

    override fun onCreate() {
        super.onCreate()
        println("🔍 [ADB] AdbDetectionService onCreate")
        
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        toneGenerator = ToneGenerator(AudioManager.STREAM_ALARM, 100)
        handler = Handler(Looper.getMainLooper())
        
        registerUsbReceiver()
        startAdbMonitoring()
        
        println("✅ [ADB] AdbDetectionService iniciado")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Detección ADB",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Servicio de detección de conexión ADB"
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Protección ADB Activa")
            .setContentText("Monitoreando conexiones de depuración")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun registerUsbReceiver() {
        try {
            usbReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    when (intent?.action) {
                        UsbManager.ACTION_USB_DEVICE_ATTACHED,
                        UsbManager.ACTION_USB_DEVICE_DETACHED,
                        Intent.ACTION_POWER_CONNECTED,
                        Intent.ACTION_POWER_DISCONNECTED -> {
                            println("🔌 [ADB] Cambio en conexión USB detectado")
                            checkAdbStatus()
                        }
                    }
                }
            }
            
            val filter = IntentFilter().apply {
                addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
                addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
                addAction(Intent.ACTION_POWER_CONNECTED)
                addAction(Intent.ACTION_POWER_DISCONNECTED)
            }
            
            registerReceiver(usbReceiver, filter)
            isReceiverRegistered = true
            println("✅ [ADB] USB BroadcastReceiver registrado")
        } catch (e: Exception) {
            println("❌ [ADB] Error registrando receiver: ${e.message}")
        }
    }

    private fun startAdbMonitoring() {
        adbCheckRunnable = object : Runnable {
            override fun run() {
                checkAdbStatus()
                handler.postDelayed(this, 2000) // Verificar cada 2 segundos
            }
        }
        handler.post(adbCheckRunnable)
    }

    private fun checkAdbStatus() {
        Thread {
            try {
                val isConnected = isAdbEnabled() && isUsbConnected()
                
                if (isConnected != isAdbConnected) {
                    isAdbConnected = isConnected
                    
                    if (isAdbConnected) {
                        println("🚨 [ADB] ¡ADB DETECTADO! Iniciando protocolo de seguridad")
                        onAdbDetected()
                    } else {
                        println("✅ [ADB] ADB desconectado - Restaurando")
                        onAdbDisconnected()
                    }
                }
            } catch (e: Exception) {
                println("❌ [ADB] Error verificando ADB: ${e.message}")
            }
        }.start()
    }

    private fun isAdbEnabled(): Boolean {
        return try {
            android.provider.Settings.Global.getInt(
                contentResolver,
                android.provider.Settings.Global.ADB_ENABLED,
                0
            ) == 1
        } catch (e: Exception) {
            false
        }
    }

    private fun isUsbConnected(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec("getprop sys.usb.state")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val usbState = reader.readLine() ?: ""
            reader.close()
            
            // Detectar si está en modo ADB/depuración
            usbState.contains("adb") || usbState.contains("mtp,adb") || usbState.contains("ptp,adb")
        } catch (e: Exception) {
            false
        }
    }

    private fun onAdbDetected() {
        println("🚨🚨🚨 [ADB] PROTOCOLO DE SEGURIDAD ACTIVADO")
        
        // 1. Guardar estado de alerta ADB
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean("is_adb_alert", true)
            putBoolean("is_locked", true)
            putLong("adb_detection_time", System.currentTimeMillis())
            apply()
        }
        
        // 2. Mostrar pantalla de bloqueo de seguridad
        val lockIntent = Intent(this, LockScreenActivity::class.java)
        lockIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        startActivity(lockIntent)
        
        // 3. Iniciar vibración continua
        startVibration()
        
        // 4. Iniciar sonido BEEP
        startBeeping()
        
        println("✅ [ADB] Protocolo de seguridad completamente activado")
    }

    private fun onAdbDisconnected() {
        println("🔓 [ADB] ADB desconectado - Restaurando estado normal")
        
        // 1. Detener vibración y sonido
        stopVibration()
        stopBeeping()
        
        // 2. Limpiar estado de alerta ADB
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean("is_adb_alert", false)
            putBoolean("is_locked", false)
            apply()
        }
        
        // 3. Cerrar pantalla de bloqueo
        val unlockIntent = Intent("com.example.security_app.UNLOCK_DEVICE")
        sendBroadcast(unlockIntent)
        
        println("✅ [ADB] Estado normal restaurado")
    }

    private fun startVibration() {
        vibrateRunnable = object : Runnable {
            override fun run() {
                if (isAdbConnected) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(500)
                    }
                    handler.postDelayed(this, 1000) // Vibrar cada segundo
                }
            }
        }
        handler.post(vibrateRunnable)
    }

    private fun stopVibration() {
        try {
            handler.removeCallbacks(vibrateRunnable)
            vibrator.cancel()
        } catch (e: Exception) {
            println("⚠️ [ADB] Error deteniendo vibración: ${e.message}")
        }
    }

    private fun startBeeping() {
        beepRunnable = object : Runnable {
            override fun run() {
                if (isAdbConnected) {
                    try {
                        toneGenerator.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 200)
                    } catch (e: Exception) {
                        println("⚠️ [ADB] Error reproduciendo beep: ${e.message}")
                    }
                    handler.postDelayed(this, 5000) // BEEP cada 5 segundos
                }
            }
        }
        handler.post(beepRunnable)
    }

    private fun stopBeeping() {
        try {
            handler.removeCallbacks(beepRunnable)
            toneGenerator.stopTone()
        } catch (e: Exception) {
            println("⚠️ [ADB] Error deteniendo beep: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        println("💀 [ADB] AdbDetectionService onDestroy")
        
        stopVibration()
        stopBeeping()
        
        try {
            handler.removeCallbacksAndMessages(null)
            toneGenerator.release()
        } catch (e: Exception) {
            println("⚠️ [ADB] Error en cleanup: ${e.message}")
        }
        
        if (isReceiverRegistered) {
            try {
                unregisterReceiver(usbReceiver)
            } catch (e: Exception) {
                println("⚠️ [ADB] Error desregistrando receiver: ${e.message}")
            }
        }
    }
}