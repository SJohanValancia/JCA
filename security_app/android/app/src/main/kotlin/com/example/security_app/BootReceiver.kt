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
                reactivateLockdown(context)
                
                val lockPrefs = context.getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
                val wasLocked = lockPrefs.getBoolean("is_locked", false)
                val isAdbAlert = lockPrefs.getBoolean("is_adb_alert", false)
                
                if (wasLocked || isAdbAlert) {
                    println("🚨 Dispositivo estaba bloqueado - Restaurando bloqueo")
                    
                    Handler(Looper.getMainLooper()).postDelayed({
                        val lockIntent = Intent(context, LockScreenActivity::class.java)
                        lockIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                        context.startActivity(lockIntent)
                        println("✅ LockScreenActivity lanzada después de reinicio")
                    }, 3000)
                }
                
                val securePrefs = context.getSharedPreferences(
                    "flutter.flutter_secure_storage",
                    Context.MODE_PRIVATE
                )
                val token = securePrefs.getString("flutter.token", null)
                
                if (token != null) {
                    println("✅ Sesión activa encontrada - Iniciando servicios")
                    
                    // ✅ VERIFICAR SI ES VENDEDOR
                    val userJson = securePrefs.getString("flutter.user", null)
                    if (userJson != null) {
                        try {
                            val jsonObj = org.json.JSONObject(userJson)
                            val rol = jsonObj.optString("rol", "dueno")
                            
if (rol == "vendedor") {
    println("🛒 [BOOT] Vendedor detectado - Iniciando servicios")
    
    // LocationTrackingService
    val locationIntent = Intent(context, LocationTrackingService::class.java)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        context.startForegroundService(locationIntent)
    } else {
        context.startService(locationIntent)
    }
    
    // ✅ NUEVO: LocationMonitorService
    val monitorIntent = Intent(context, LocationMonitorService::class.java)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        context.startForegroundService(monitorIntent)
    } else {
        context.startService(monitorIntent)
    }
    
    println("✅ [BOOT] Servicios de ubicación iniciados")
}
                        } catch (e: Exception) {
                            println("⚠️ [BOOT] Error parseando rol: ${e.message}")
                        }
                    }
                    
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
                
                devicePolicyManager.addUserRestriction(adminComponent, "no_debugging_features")
                devicePolicyManager.addUserRestriction(adminComponent, "no_config_credentials")
                devicePolicyManager.addUserRestriction(adminComponent, "no_factory_reset")
                devicePolicyManager.setUninstallBlocked(adminComponent, context.packageName, true)
                
                println("✅ ========== LOCKDOWN REACTIVADO ==========")
            }
        } catch (e: Exception) {
            println("❌ Error reactivando lockdown: ${e.message}")
        }
    }
}