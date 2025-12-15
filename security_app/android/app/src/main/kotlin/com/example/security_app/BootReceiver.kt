package com.example.security_app

import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            println("📱 Dispositivo reiniciado - verificando sesión y bloqueo")
            
            try {
                // ✅ REACTIVAR LOCKDOWN DESPUÉS DEL REINICIO
                reactivateLockdown(context)
                
                // ✅ VERIFICAR SI ESTABA BLOQUEADO ANTES DE REINICIAR
                val lockPrefs = context.getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
                val wasLocked = lockPrefs.getBoolean("is_locked", false)
                val isAdbAlert = lockPrefs.getBoolean("is_adb_alert", false)
                
                if (wasLocked || isAdbAlert) {
                    println("🚨 Dispositivo estaba bloqueado - Restaurando bloqueo")
                    
                    // ✅ Esperar 3 segundos para que los servicios inicien
                    Handler(Looper.getMainLooper()).postDelayed({
                        val lockIntent = Intent(context, LockScreenActivity::class.java)
                        lockIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                        context.startActivity(lockIntent)
                        println("✅ LockScreenActivity lanzada después de reinicio")
                    }, 3000) // 3 segundos de delay
                }
                
                // ✅ VERIFICAR SI HAY TOKEN (SESIÓN ACTIVA)
                val securePrefs = context.getSharedPreferences(
                    "flutter.flutter_secure_storage",
                    Context.MODE_PRIVATE
                )
                val token = securePrefs.getString("flutter.token", null)
                
                if (token != null) {
                    println("✅ Sesión activa encontrada - Iniciando servicios")
                    
                    // Iniciar LockMonitorService
                    val lockServiceIntent = Intent(context, LockMonitorService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(lockServiceIntent)
                    } else {
                        context.startService(lockServiceIntent)
                    }
                    
                    // Iniciar AdbDetectionService
                    val adbServiceIntent = Intent(context, AdbDetectionService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(adbServiceIntent)
                    } else {
                        context.startService(adbServiceIntent)
                    }
                    
                    println("✅ Servicios iniciados")
                } else {
                    println("ℹ️ No hay sesión activa")
                }
            } catch (e: Exception) {
                println("❌ Error en boot: ${e.message}")
            }
        }
    }
    
    private fun reactivateLockdown(context: Context) {
        try {
            val devicePolicyManager = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(context, MyDeviceAdminReceiver::class.java)
            
            if (devicePolicyManager.isDeviceOwnerApp(context.packageName)) {
                println("🔒 ========== REACTIVANDO LOCKDOWN DESPUÉS DE REINICIO ==========")
                
                // Bloquear depuración USB
                devicePolicyManager.addUserRestriction(adminComponent, "no_debugging_features")
                println("✅ Depuración USB bloqueada")
                
                // Ocultar opciones de desarrollador
                devicePolicyManager.addUserRestriction(adminComponent, "no_config_credentials")
                println("✅ Opciones de desarrollador ocultas")
                
                // Bloquear factory reset
                devicePolicyManager.addUserRestriction(adminComponent, "no_factory_reset")
                println("✅ Factory reset bloqueado")
                
                // Proteger app
                devicePolicyManager.setUninstallBlocked(adminComponent, context.packageName, true)
                println("✅ App protegida")
                
                println("✅ ========== LOCKDOWN REACTIVADO ==========")
            }
        } catch (e: Exception) {
            println("❌ Error reactivando lockdown: ${e.message}")
        }
    }
}