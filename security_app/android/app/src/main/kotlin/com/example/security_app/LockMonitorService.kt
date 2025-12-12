package com.example.security_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class LockMonitorService : Service() {
    private lateinit var handler: Handler
    private lateinit var checkRunnable: Runnable

    override fun onCreate() {
        super.onCreate()
        
        // Crear notificación persistente
        createNotificationChannel()
        val notification = createNotification()
        startForeground(1, notification)

        // Configurar handler para verificación constante
        handler = Handler(Looper.getMainLooper())
        checkRunnable = object : Runnable {
            override fun run() {
                checkAndEnforceLock()
                handler.postDelayed(this, 1000) // Verificar cada segundo
            }
        }
        handler.post(checkRunnable)
    }

    private fun checkAndEnforceLock() {
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        val isLocked = prefs.getBoolean("is_locked", false)

        if (isLocked) {
            // Verificar si LockScreenActivity está en primer plano
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val tasks = activityManager.appTasks
            
            var isLockScreenActive = false
            if (tasks.isNotEmpty()) {
                val topActivity = tasks[0].taskInfo.topActivity
                if (topActivity?.className == LockScreenActivity::class.java.name) {
                    isLockScreenActive = true
                }
            }

            // Si NO está activa, forzar su apertura
            if (!isLockScreenActive) {
                val intent = Intent(this, LockScreenActivity::class.java)
                intent.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or
                    Intent.FLAG_ACTIVITY_NO_HISTORY or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                )
                startActivity(intent)
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "lock_monitor",
                "Monitoreo de Bloqueo",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantiene el dispositivo bloqueado"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, "lock_monitor")
            .setContentTitle("Dispositivo Bloqueado")
            .setContentText("Sistema de seguridad activo")
            .setSmallIcon(R.drawable.ic_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY // Reiniciar si el servicio es matado
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(checkRunnable)
        
        // Si el dispositivo sigue bloqueado, reiniciar el servicio
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        val isLocked = prefs.getBoolean("is_locked", false)
        
        if (isLocked) {
            val intent = Intent(this, LockMonitorService::class.java)
            startForegroundService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}