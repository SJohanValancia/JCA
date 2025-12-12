package com.example.security_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

class LockMonitorService : Service() {

    private lateinit var handler: Handler
    private lateinit var checkRunnable: Runnable
    private val client = OkHttpClient()
    private val baseUrl = "https://jca-labd.onrender.com"

    override fun onCreate() {
        super.onCreate()

        println("🚀 LockMonitorService iniciado")

        createNotificationChannel()
        
        // ✅ CRÍTICO: Especificar el tipo de servicio para Android 14+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                1, 
                createNotification(), 
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(1, createNotification())
        }

        handler = Handler(Looper.getMainLooper())
        checkRunnable = Runnable {
            checkLockStatusWithBackend()
            handler.postDelayed(checkRunnable, 3000)
        }

        handler.post(checkRunnable)
    }

    private fun checkLockStatusWithBackend() {
        Thread {
            try {
                val securePrefs = getSharedPreferences(
                    "flutter.flutter_secure_storage",
                    Context.MODE_PRIVATE
                )
                val token = securePrefs.getString("flutter.token", null)

                if (token == null) {
                    println("⚠️ Token no encontrado, apagando servicio")
                    stopSelfSafely()
                    return@Thread
                }

                val request = Request.Builder()
                    .url("$baseUrl/api/lock/check")
                    .addHeader("Authorization", "Bearer $token")
                    .get()
                    .build()

                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) return@use

                    val body = response.body?.string() ?: "{}"
                    val json = JSONObject(body)

                    val backendLocked = json.optBoolean("isLocked", false)
                    val message = json.optString("lockMessage", "Dispositivo bloqueado")

                    if (backendLocked) {
                        activateLockIfNeeded(message)
                    } else {
                        deactivateLockIfNeeded()
                    }
                }

            } catch (e: Exception) {
                println("❌ Error backend: ${e.message}")
            }
        }.start()
    }

    private fun activateLockIfNeeded(message: String) {
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)

        if (prefs.getBoolean("is_locked", false)) return

        println("🔒 Activando bloqueo")

        prefs.edit()
            .putBoolean("is_locked", true)
            .putString("lock_message", message)
            .apply()

        val intent = Intent(this, LockScreenActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        startActivity(intent)
    }

    private fun deactivateLockIfNeeded() {
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)

        if (!prefs.getBoolean("is_locked", false)) {
            stopSelfSafely()
            return
        }

        println("🔓 Desbloqueando")

        prefs.edit().putBoolean("is_locked", false).apply()
        sendBroadcast(Intent("com.example.security_app.UNLOCK_DEVICE"))
        stopSelfSafely()
    }

    private fun stopSelfSafely() {
        try {
            handler.removeCallbacksAndMessages(null)
        } catch (_: Exception) {}

        stopForeground(true)
        stopSelf()

        println("🛑 LockMonitorService detenido")
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            handler.removeCallbacksAndMessages(null)
        } catch (_: Exception) {}
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "lock_monitor",
                "Monitoreo de Seguridad",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, "lock_monitor")
            .setContentTitle("JCA Security")
            .setContentText("Monitoreo de seguridad activo")
            .setSmallIcon(R.drawable.ic_lock)
            .setOngoing(true)
            .build()
    }
}