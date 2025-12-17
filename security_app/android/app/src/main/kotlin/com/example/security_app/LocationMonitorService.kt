package com.example.security_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationCompat

class LocationMonitorService : Service() {
    private lateinit var handler: Handler
    private lateinit var checkRunnable: Runnable
    private var checkCount = 0

    companion object {
        private const val CHANNEL_ID = "location_monitor_channel"
        private const val NOTIFICATION_ID = 4
    }

    override fun onCreate() {
        super.onCreate()
        println("📍 [LOC_MONITOR] LocationMonitorService onCreate")
        
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        
        startLocationMonitoring()
        
        println("✅ [LOC_MONITOR] Servicio de monitoreo iniciado")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Monitoreo de Ubicación",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Verifica que la ubicación esté activa"
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🛡️ Monitoreo Activo")
            .setContentText("Protegiendo configuración de ubicación")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun startLocationMonitoring() {
        handler = Handler(Looper.getMainLooper())
        checkRunnable = object : Runnable {
            override fun run() {
                checkCount++
                println("🔍 [LOC_MONITOR #$checkCount] Verificando ubicación...")
                checkLocationStatus()
                handler.postDelayed(this, 3000) // ✅ Cada 3 segundos
            }
        }
        handler.post(checkRunnable)
    }

    private fun checkLocationStatus() {
        try {
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val isGpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
            val isNetworkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

            println("📍 [LOC_MONITOR #$checkCount] GPS: $isGpsEnabled, Network: $isNetworkEnabled")

            if (!isGpsEnabled || !isNetworkEnabled) {
                println("⚠️ [LOC_MONITOR #$checkCount] ¡UBICACIÓN DESACTIVADA!")
                
                // ✅ VERIFICAR SI ES VENDEDOR
                val securePrefs = getSharedPreferences(
                    "flutter.flutter_secure_storage",
                    Context.MODE_PRIVATE
                )
                val userJson = securePrefs.getString("flutter.user", null)
                
                if (userJson != null) {
                    try {
                        val jsonObj = org.json.JSONObject(userJson)
                        val rol = jsonObj.optString("rol", "dueno")
                        
                        if (rol == "vendedor") {
                            println("🚨 [LOC_MONITOR] Vendedor intentó desactivar ubicación - REACTIVANDO")
                            enableLocationForced()
                        }
                    } catch (e: Exception) {
                        println("⚠️ [LOC_MONITOR] Error parseando rol: ${e.message}")
                    }
                }
            } else {
                println("✅ [LOC_MONITOR #$checkCount] Ubicación activa correctamente")
            }
        } catch (e: Exception) {
            println("❌ [LOC_MONITOR] Error verificando ubicación: ${e.message}")
        }
    }

    private fun enableLocationForced() {
        try {
            println("🔧 [LOC_MONITOR] Intentando forzar reactivación de GPS...")
            
            // ✅ Método 1: Intentar habilitar mediante Settings
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    Settings.Secure.putInt(
                        contentResolver,
                        Settings.Secure.LOCATION_MODE,
                        Settings.Secure.LOCATION_MODE_HIGH_ACCURACY
                    )
                    println("✅ [LOC_MONITOR] GPS reactivado mediante Settings")
                }
            } catch (e: Exception) {
                println("⚠️ [LOC_MONITOR] No se pudo usar Settings: ${e.message}")
            }

            // ✅ Método 2: Reiniciar LocationTrackingService
            try {
                val locationIntent = Intent(this, LocationTrackingService::class.java)
                stopService(locationIntent)
                
                Handler(Looper.getMainLooper()).postDelayed({
                    startForegroundService(locationIntent)
                    println("✅ [LOC_MONITOR] LocationTrackingService reiniciado")
                }, 1000)
            } catch (e: Exception) {
                println("⚠️ [LOC_MONITOR] Error reiniciando servicio: ${e.message}")
            }

            // ✅ Método 3: Mostrar alerta al usuario
            showLocationDisabledAlert()

        } catch (e: Exception) {
            println("❌ [LOC_MONITOR] Error forzando ubicación: ${e.message}")
        }
    }

    private fun showLocationDisabledAlert() {
        try {
            val lockPrefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
            lockPrefs.edit().apply {
                putBoolean("is_locked", true)
                putString("lock_message", "⚠️ NO DESACTIVES LA UBICACIÓN\n\nEsta acción está prohibida.")
                apply()
            }

            val lockIntent = Intent(this, LockScreenActivity::class.java)
            lockIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            startActivity(lockIntent)
            
            println("🚨 [LOC_MONITOR] Pantalla de bloqueo mostrada por desactivar ubicación")
            
            // ✅ Auto-desbloquear después de 5 segundos
            Handler(Looper.getMainLooper()).postDelayed({
                lockPrefs.edit().putBoolean("is_locked", false).apply()
                val unlockIntent = Intent("com.example.security_app.UNLOCK_DEVICE")
                sendBroadcast(unlockIntent)
                println("✅ [LOC_MONITOR] Auto-desbloqueado después de alerta")
            }, 5000)

        } catch (e: Exception) {
            println("❌ [LOC_MONITOR] Error mostrando alerta: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        println("💀 [LOC_MONITOR] LocationMonitorService onDestroy")
        
        try {
            handler.removeCallbacksAndMessages(null)
        } catch (e: Exception) {
            println("⚠️ [LOC_MONITOR] Error en cleanup: ${e.message}")
        }
        
        // ✅ Reiniciar el servicio automáticamente
        val restartIntent = Intent(applicationContext, LocationMonitorService::class.java)
        startService(restartIntent)
    }
}