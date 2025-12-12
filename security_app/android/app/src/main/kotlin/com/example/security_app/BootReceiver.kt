package com.example.security_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            println("📱 Dispositivo reiniciado - verificando estado")
            
            val prefs = context.getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
            val isLocked = prefs.getBoolean("is_locked", false)

            if (isLocked) {
                println("🔒 Dispositivo bloqueado - iniciando servicio")
                try {
                    val serviceIntent = Intent(context, LockMonitorService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                    println("✅ Servicio iniciado correctamente")
                } catch (e: Exception) {
                    println("❌ Error iniciando servicio en boot: ${e.message}")
                }
            } else {
                println("✅ Dispositivo NO bloqueado - no se inicia servicio")
            }
        }
    }
}