package com.example.security_app

import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class LockMonitorService : Service() {
    private lateinit var handler: Handler
    private lateinit var screenReceiver: BroadcastReceiver
    private var isReceiverRegistered = false
    
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()
    private val baseUrl = "https://jca-labd.onrender.com"
    private lateinit var backendCheckRunnable: Runnable
    private var checkCount = 0

    companion object {
        private const val CHANNEL_ID = "lock_monitor_channel"
        private const val NOTIFICATION_ID = 1
        var isRunning = false 
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        println("🔧 [SERVICE] LockMonitorService onCreate - INICIANDO")
        
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        
        registerScreenReceiver()
        startBackendMonitoring()
        
        println("✅ [SERVICE] LockMonitorService COMPLETAMENTE OPERACIONAL")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        println("▶️ [SERVICE] onStartCommand")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Monitoreo de Seguridad",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Servicio de monitoreo de bloqueo"
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Seguridad Activa")
            .setContentText("Monitoreando estado del dispositivo")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun registerScreenReceiver() {
        try {
            screenReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    when (intent?.action) {
                        Intent.ACTION_SCREEN_ON -> {
                            println("📱 [SERVICE] Pantalla encendida")
                            checkIfShouldLock()
                        }
                        Intent.ACTION_USER_PRESENT -> {
                            println("👤 [SERVICE] Usuario presente")
                            checkIfShouldLock()
                        }
                    }
                }
            }
            
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_USER_PRESENT)
            }
            
            registerReceiver(screenReceiver, filter)
            isReceiverRegistered = true
            println("✅ [SERVICE] BroadcastReceiver registrado")
        } catch (e: Exception) {
            println("❌ [SERVICE] Error registrando receiver: ${e.message}")
        }
    }

    private fun startBackendMonitoring() {
        handler = Handler(Looper.getMainLooper())
        backendCheckRunnable = object : Runnable {
            override fun run() {
                checkCount++
                println("🌐 [SERVICE #$checkCount] Verificando backend...")
                checkBackendLockStatus()
                handler.postDelayed(this, 10000) // Cada 10 segundos
            }
        }
        
        handler.post(backendCheckRunnable)
        println("✅ [SERVICE] Monitoreo de backend iniciado")
    }

    private fun checkBackendLockStatus() {
        Thread {
            try {
                val securePrefs = getSharedPreferences(
                    "flutter.flutter_secure_storage",
                    Context.MODE_PRIVATE
                )
                val token = securePrefs.getString("flutter.token", null)

                if (token == null) {
                    println("⚠️ [SERVICE #$checkCount] No hay token")
                    return@Thread
                }

                val request = Request.Builder()
                    .url("$baseUrl/api/lock/check")
                    .addHeader("Authorization", "Bearer $token")
                    .build()

                val response = client.newCall(request).execute()

                if (response.isSuccessful) {
                    val body = response.body?.string() ?: ""
                    val json = JSONObject(body)
                    val shouldBeLocked = json.getBoolean("isLocked")
                    val message = json.optString("lockMessage", "Dispositivo bloqueado")

                    val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
                    val currentlyLocked = prefs.getBoolean("is_locked", false)

                    println("📊 [SERVICE #$checkCount] Backend: $shouldBeLocked | Local: $currentlyLocked")

                    if (shouldBeLocked && !currentlyLocked) {
                        println("🔒 [SERVICE #$checkCount] ¡Debe bloquearse!")
                        lockDeviceNow(message)
                    } else if (!shouldBeLocked && currentlyLocked) {
                        println("🔓 [SERVICE #$checkCount] ¡Debe desbloquearse!")
                        unlockDeviceNow()
                    }
                }

            } catch (e: Exception) {
                println("❌ [SERVICE #$checkCount] Error: ${e.message}")
            }
        }.start()
    }

    private fun checkIfShouldLock() {
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        val shouldBeLocked = prefs.getBoolean("is_locked", false)
        
        if (shouldBeLocked) {
            println("🔒 [SERVICE] Debe estar bloqueado - mostrando pantalla")
            lockDeviceNow(prefs.getString("lock_message", "Dispositivo bloqueado") ?: "")
        }
    }

private fun lockDeviceNow(message: String) {
    try {
        println("🔒 [SERVICE] ===== INICIANDO PROCESO DE BLOQUEO =====")
        
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString("lock_message", message)
            putBoolean("is_locked", true)
            putBoolean("tracking_active", true)
            putLong("lock_activation_time", System.currentTimeMillis())
            apply()
        }
        println("✅ [SERVICE] Estado guardado")

        // ✅ INICIAR SERVICIO DE UBICACIÓN
        try {
            println("📍 [SERVICE] Iniciando LocationTrackingService...")
            val locationIntent = Intent(this, LocationTrackingService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(locationIntent)
            } else {
                startService(locationIntent)
            }
            
            // Esperar 3 segundos
            Thread.sleep(3000)
            println("✅ [SERVICE] LocationTrackingService iniciado")
            
        } catch (e: Exception) {
            println("❌ [SERVICE] Error iniciando ubicación: ${e.message}")
        }

        // Lanzar pantalla de bloqueo
        val intent = Intent(this, LockScreenActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        startActivity(intent)
        
        println("✅ [SERVICE] ===== BLOQUEO COMPLETADO =====")
    } catch (e: Exception) {
        println("❌ [SERVICE] Error: ${e.message}")
    }
}

    // ✅ Iniciar seguimiento de ubicación
    private fun startLocationTracking() {
        try {
            val locationIntent = Intent("com.example.security_app.START_LOCATION_TRACKING")
            sendBroadcast(locationIntent)
            println("✅ [SERVICE] Solicitud de ubicación enviada")
        } catch (e: Exception) {
            println("❌ [SERVICE] Error enviando solicitud de ubicación: ${e.message}")
        }
    }

    private fun unlockDeviceNow() {
        try {
            val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putBoolean("is_locked", false)
                putBoolean("is_adb_alert", false) // ✅ Limpiar alerta ADB también
                apply()
            }
            println("✅ [SERVICE] SharedPreferences actualizado")

            // ✅ Enviar broadcast múltiples veces para asegurar que llegue
            repeat(3) { attempt ->
                try {
                    val unlockIntent = Intent("com.example.security_app.UNLOCK_DEVICE")
                    sendBroadcast(unlockIntent)
                    println("📡 [SERVICE] Broadcast enviado (intento ${attempt + 1})")
                    Thread.sleep(200) // Esperar 200ms entre intentos
                } catch (e: Exception) {
                    println("⚠️ [SERVICE] Error enviando broadcast: ${e.message}")
                }
            }
            
            // ✅ Forzar cierre de LockScreenActivity si existe
            try {
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val tasks = activityManager.appTasks
                
                for (task in tasks) {
                    val taskInfo = task.taskInfo
                    val className = taskInfo.baseActivity?.className
                    
                    if (className?.contains("LockScreenActivity") == true) {
                        println("🗑️ [SERVICE] Cerrando LockScreenActivity forzadamente")
                        task.finishAndRemoveTask()
                    }
                }
            } catch (e: Exception) {
                println("⚠️ [SERVICE] Error cerrando activity: ${e.message}")
            }
            
            println("✅ [SERVICE] Comando de desbloqueo completado")
        } catch (e: Exception) {
            println("❌ [SERVICE] Error desbloqueando: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        println("💀 [SERVICE] onDestroy")
        
        try {
            handler.removeCallbacksAndMessages(null)
        } catch (e: Exception) {
            println("⚠️ [SERVICE] Error deteniendo handler: ${e.message}")
        }
        
        if (isReceiverRegistered) {
            try {
                unregisterReceiver(screenReceiver)
            } catch (e: Exception) {
                println("⚠️ [SERVICE] Error desregistrando receiver: ${e.message}")
            }
        }
        
        // ✅ Reiniciar el servicio automáticamente
        println("🔄 [SERVICE] Intentando reiniciar servicio...")
        val restartIntent = Intent(applicationContext, LockMonitorService::class.java)
        startService(restartIntent)
    }
}