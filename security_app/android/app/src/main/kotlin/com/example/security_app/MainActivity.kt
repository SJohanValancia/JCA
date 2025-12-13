package com.example.security_app

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle  // ✅ AGREGAR ESTE IMPORT
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.security_app/device_owner"
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var adminComponent: ComponentName

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // ✅ VERIFICAR SI HAY SESIÓN ACTIVA Y INICIAR SERVICIO
        checkAndStartMonitorService()
    }

    private fun checkAndStartMonitorService() {
        try {
            val securePrefs = getSharedPreferences(
                "flutter.flutter_secure_storage",
                Context.MODE_PRIVATE
            )
            val token = securePrefs.getString("flutter.token", null)
            
            if (token != null) {
                println("✅ Token encontrado - Iniciando servicio de monitoreo")
                val serviceIntent = Intent(this, LockMonitorService::class.java)
                startForegroundService(serviceIntent)
            } else {
                println("ℹ️ No hay sesión activa")
            }
        } catch (e: Exception) {
            println("❌ Error verificando sesión: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponent = ComponentName(this, MyDeviceAdminReceiver::class.java)

        println("✅ Registrando MethodChannel: $CHANNEL")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            println("📞 Método llamado: ${call.method}")
            when (call.method) {
                "lockDevice" -> {
                    val message = call.argument<String>("message") ?: "Dispositivo bloqueado"
                    val success = lockDevice(message)
                    result.success(success)
                }
                "unlockDevice" -> {
                    val success = unlockDevice()
                    result.success(success)
                }
                "isLocked" -> {
                    val isLocked = isDeviceLocked()
                    println("🔍 isLocked llamado, retornando: $isLocked")
                    result.success(isLocked)
                }
                "startMonitorService" -> {
                    try {
                        val serviceIntent = Intent(this, LockMonitorService::class.java)
                        startForegroundService(serviceIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        println("❌ Error iniciando servicio: ${e.message}")
                        result.success(false)
                    }
                }
                "forceUnlock" -> {
                    val success = forceUnlockDevice()
                    result.success(success)
                }
                else -> {
                    println("❌ Método no implementado: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

 private fun lockDevice(message: String): Boolean {
    return try {
        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
            println("🔒 Iniciando proceso de bloqueo")
            
            val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putString("lock_message", message)
                putBoolean("is_locked", true)
                putLong("lock_activation_time", System.currentTimeMillis())  // ✅ NUEVO: Almacenar timestamp de activación
                apply()
            }
            println("✅ Estado guardado en SharedPreferences")

                try {
                    val serviceIntent = Intent(this, LockMonitorService::class.java)
                    startForegroundService(serviceIntent)
                    println("✅ LockMonitorService iniciado")
                } catch (e: Exception) {
                    println("❌ Error con servicio: ${e.message}")
                }
                
                Handler(Looper.getMainLooper()).postDelayed({
                    val intent = Intent(this, LockScreenActivity::class.java)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                    startActivity(intent)
                    println("✅ LockScreenActivity lanzada")
                }, 500)

                true
            } else {
                println("❌ No es Device Owner")
                false
            }
        } catch (e: Exception) {
            println("❌ Error en lockDevice: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    private fun unlockDevice(): Boolean {
        return try {
            println("🔓 Iniciando desbloqueo completo")
            
            val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putBoolean("is_locked", false)
                apply()
            }
            println("✅ SharedPreferences actualizado")
            
            try {
                val unlockIntent = Intent("com.example.security_app.UNLOCK_DEVICE")
                sendBroadcast(unlockIntent)
                println("📡 Broadcast enviado")
            } catch (e: Exception) {
                println("⚠️ Error enviando broadcast: ${e.message}")
            }
            
            try {
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val tasks = activityManager.appTasks
                
                for (task in tasks) {
                    val taskInfo = task.taskInfo
                    val className = taskInfo.baseActivity?.className
                    
                    if (className == "com.example.security_app.LockScreenActivity") {
                        println("🗑️ Cerrando LockScreenActivity")
                        task.finishAndRemoveTask()
                    }
                }
            } catch (e: Exception) {
                println("❌ Error cerrando activity: ${e.message}")
            }
            
            val serviceIntent = Intent(this, LockMonitorService::class.java)
            stopService(serviceIntent)
            println("✅ Servicio detenido")
            
            try {
                if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                    devicePolicyManager.setKeyguardDisabled(adminComponent, false)
                    devicePolicyManager.setStatusBarDisabled(adminComponent, false)
                    devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf())
                    println("✅ Device Owner restaurado")
                }
            } catch (e: Exception) {
                println("⚠️ Error restaurando Device Owner: ${e.message}")
            }
            
            println("✅ Desbloqueo completo exitoso")
            true
            
        } catch (e: Exception) {
            println("❌ Error crítico en unlockDevice: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    private fun forceUnlockDevice(): Boolean {
        return try {
            println("🚨 FORZANDO DESBLOQUEO DE EMERGENCIA")
            
            val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putBoolean("is_locked", false)
                apply()
            }
            println("✅ SharedPreferences actualizado a is_locked = false")
            
            try {
                val unlockIntent = Intent("com.example.security_app.UNLOCK_DEVICE")
                sendBroadcast(unlockIntent)
                println("📡 Broadcast de desbloqueo enviado")
            } catch (e: Exception) {
                println("⚠️ Error enviando broadcast: ${e.message}")
            }
            
            try {
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val tasks = activityManager.appTasks
                
                println("🔍 Buscando LockScreenActivity en ${tasks.size} tareas")
                
                for (task in tasks) {
                    val taskInfo = task.taskInfo
                    val className = taskInfo.baseActivity?.className
                    println("📋 Tarea encontrada: $className")
                    
                    if (className?.contains("LockScreenActivity") == true) {
                        println("🗑️ Finalizando LockScreenActivity")
                        task.finishAndRemoveTask()
                        println("✅ LockScreenActivity finalizada exitosamente")
                    }
                }
            } catch (e: Exception) {
                println("❌ Error finalizando activity: ${e.message}")
                e.printStackTrace()
            }
            
            try {
                val serviceIntent = Intent(this, LockMonitorService::class.java)
                stopService(serviceIntent)
                println("✅ LockMonitorService detenido")
            } catch (e: Exception) {
                println("⚠️ Error deteniendo servicio: ${e.message}")
            }
            
            try {
                if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                    devicePolicyManager.setKeyguardDisabled(adminComponent, false)
                    devicePolicyManager.setStatusBarDisabled(adminComponent, false)
                    devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf())
                    println("✅ Device Owner restaurado a configuración normal")
                }
            } catch (e: Exception) {
                println("⚠️ Error restaurando Device Owner: ${e.message}")
            }
            
            println("✅ ForceUnlock completado exitosamente")
            true
            
        } catch (e: Exception) {
            println("❌ Error CRÍTICO en forceUnlock: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    private fun isDeviceLocked(): Boolean {
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        return prefs.getBoolean("is_locked", false)
    }
}