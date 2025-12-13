package com.example.security_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
override fun onReceive(context: Context, intent: Intent) {
    if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
        println("📱 Dispositivo reiniciado - verificando sesión")
        
        try {
            // ✅ VERIFICAR SI HAY TOKEN (SESIÓN ACTIVA)
            val securePrefs = context.getSharedPreferences(
                "flutter.flutter_secure_storage",
                Context.MODE_PRIVATE
            )
            val token = securePrefs.getString("flutter.token", null)
            
            if (token != null) {
                println("✅ Sesión activa encontrada - Iniciando servicio")
                val serviceIntent = Intent(context, LockMonitorService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } else {
                println("ℹ️ No hay sesión activa, no se inicia servicio")
            }
        } catch (e: Exception) {
            println("❌ Error en boot: ${e.message}")
        }
    }
}
}