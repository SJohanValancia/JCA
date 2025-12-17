package com.example.security_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class PaymentNotificationService : Service() {
    private lateinit var handler: Handler
    private lateinit var checkRunnable: Runnable
    private var checkCount = 0

    companion object {
        private const val CHANNEL_ID = "payment_notification_channel"
        private const val NOTIFICATION_ID = 5
    }

    override fun onCreate() {
        super.onCreate()
        println("💰 [PAYMENT] PaymentNotificationService onCreate")
        
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        
        startPaymentCheck()
        
        println("✅ [PAYMENT] Servicio iniciado")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Monitoreo de Pagos",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Verifica pagos pendientes"
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("💰 Monitor de Pagos")
            .setContentText("Verificando pagos pendientes")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun startPaymentCheck() {
        handler = Handler(Looper.getMainLooper())
        checkRunnable = object : Runnable {
            override fun run() {
                checkCount++
                println("💰 [PAYMENT #$checkCount] Verificando pagos...")
                
                // Enviar broadcast a Flutter para verificar pagos
                try {
                    val intent = Intent("com.example.security_app.CHECK_PAYMENT")
                    sendBroadcast(intent)
                    println("📡 [PAYMENT] Broadcast enviado a Flutter")
                } catch (e: Exception) {
                    println("❌ [PAYMENT] Error enviando broadcast: ${e.message}")
                }
                
                // Verificar cada 12 horas (43200000 ms = 12 horas)
                handler.postDelayed(this, 43200000)
            }
        }
        
        // Primera verificación después de 5 segundos
        handler.postDelayed(checkRunnable, 5000)
    }

    override fun onDestroy() {
        super.onDestroy()
        println("💀 [PAYMENT] PaymentNotificationService onDestroy")
        
        try {
            handler.removeCallbacksAndMessages(null)
        } catch (e: Exception) {
            println("⚠️ [PAYMENT] Error en cleanup: ${e.message}")
        }
        
        // Reiniciar el servicio automáticamente
        val restartIntent = Intent(applicationContext, PaymentNotificationService::class.java)
        startService(restartIntent)
    }
}