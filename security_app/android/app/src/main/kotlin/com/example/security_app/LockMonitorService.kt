package com.example.security_app

import android.app.*
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.app.admin.DevicePolicyManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONObject
import java.io.IOException

class LockMonitorService : Service() {

    private lateinit var handler: Handler
    private lateinit var checkRunnable: Runnable
    private val client = OkHttpClient()
    private val baseUrl = "https://jca-labd.onrender.com"

    override fun onCreate() {
        super.onCreate()

        createNotificationChannel()
        val notification = createNotification()
        startForeground(1, notification)

        println("🚀 LockMonitorService iniciado")

        handler = Handler(Looper.getMainLooper())
        checkRunnable = object : Runnable {
            override fun run() {
                checkLockStatusWithBackend()
                handler.postDelayed(this, 10000) // Verificar cada 10 segundos
            }
        }
        handler.postDelayed(checkRunnable, 2000) // Primera verificación después de 2 segundos
    }

    private fun checkLockStatusWithBackend() {
        Thread {
            try {
                val prefs = getSharedPreferences("flutter.flutter_secure_storage", Context.MODE_PRIVATE)
                val token = prefs.getString("flutter.token", null)

                if (token == null) {
                    println("⚠️ No hay token guardado, no se puede verificar")
                    return@Thread
                }

                println("🌐 Verificando estado de bloqueo con backend...")

                val request = Request.Builder()
                    .url("$baseUrl/api/lock/check")
                    .addHeader("Authorization", "Bearer $token")
                    .addHeader("Content-Type", "application/json")
                    .get()
                    .build()

                client.newCall(request).execute().use { response ->
                    if (response.isSuccessful) {
                        val responseBody = response.body?.string()
                        println("📦 Response del backend: $responseBody")

                        val json = JSONObject(responseBody ?: "{}")
                        val isLocked = json.optBoolean("isLocked", false)
                        val lockMessage = json.optString("lockMessage", "Dispositivo bloqueado")

                        println("🔍 Estado recibido - isLocked: $isLocked")

                        if (isLocked) {
                            println("🔒 BLOQUEO DETECTADO - Activando pantalla de bloqueo")
                            activateLockScreen(lockMessage)
                        } else {
                            println("✅ Dispositivo NO bloqueado")
                            checkAndDeactivateLock()
                        }
                    } else {
                        println("❌ Error en response: ${response.code}")
                    }
                }
            } catch (e: Exception) {
                println("❌ Error verificando con backend: ${e.message}")
                e.printStackTrace()
            }
        }.start()
    }

    private fun activateLockScreen(message: String) {
        val localPrefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        val isAlreadyLocked = localPrefs.getBoolean("is_locked", false)

        if (!isAlreadyLocked) {
            println("🔐 Guardando estado de bloqueo local")
            localPrefs.edit().apply {
                putBoolean("is_locked", true)
                putString("lock_message", message)
                apply()
            }

            println("📱 Lanzando LockScreenActivity")
            val intent = Intent(this, LockScreenActivity::class.java)
            intent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TASK or
                Intent.FLAG_ACTIVITY_NO_HISTORY or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            )
            startActivity(intent)
        } else {
            println("ℹ️ El dispositivo ya está bloqueado localmente")
        }
    }

    private fun checkAndDeactivateLock() {
        val localPrefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        val isLocked = localPrefs.getBoolean("is_locked", false)

        if (isLocked) {
            println("🔓 Desbloqueando dispositivo localmente")
            localPrefs.edit().apply {
                putBoolean("is_locked", false)
                apply()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(checkRunnable)
        println("⚠️ LockMonitorService destruido - Reiniciando...")

        // Auto-reiniciar el servicio
        val restartIntent = Intent(this, LockMonitorService::class.java)
        startForegroundService(restartIntent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "lock_monitor",
                "Monitoreo de Seguridad",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Servicio de monitoreo de bloqueo activo"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, "lock_monitor")
            .setContentTitle("JCA Security")
            .setContentText("Sistema de seguridad activo")
            .setSmallIcon(R.drawable.ic_lock)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}