package com.example.security_app

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
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
                "protectApp" -> {
                    val success = protectAppFromUninstall()
                    result.success(success)
                }
                "lockDownDevice" -> {
                    val success = lockDownDevice()
                    result.success(success)
                }
                "releaseApp" -> {
                    val vendorId = call.argument<String>("vendorId") ?: ""
                    val success = releaseApp(vendorId)
                    result.success(success)
                }
                "isAppProtected" -> {
                    val protected = isAppProtected()
                    result.success(protected)
                }
                
                else -> {
                    println("❌ Método no implementado: ${call.method}")
                    result.notImplemented()
                }
            }
        }
        
        // ✅ Activar protección automáticamente (SOLO contra desinstalación)
        protectAppFromUninstall()
    }

    // ✅ Protección SOLO contra desinstalación manual (permite actualizaciones)
    private fun protectAppFromUninstall(): Boolean {
        return try {
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                println("🔒 ========== ACTIVANDO PROTECCIÓN CONTRA DESINSTALACIÓN ==========")
                
                // ✅ Bloquear desinstalación manual (NO bloquea actualizaciones via ADB/Play Store)
                devicePolicyManager.setUninstallBlocked(adminComponent, packageName, true)
                println("✅ App bloqueada contra desinstalación manual")
                
                // Guardar estado de protección
                val prefs = getSharedPreferences("app_protection", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("is_protected", true).apply()
                
                println("✅ ========== PROTECCIÓN ACTIVADA (actualizaciones permitidas) ==========")
                true
            } else {
                println("❌ No es Device Owner - No se puede proteger")
                false
            }
        } catch (e: Exception) {
            println("❌ Error protegiendo app: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    // ✅ Bloqueo de funciones del sistema (SIN bloquear instalación de apps)
    private fun lockDownDevice(): Boolean {
        return try {
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                println("🔒 ========== ACTIVANDO LOCKDOWN (sin bloquear instalaciones) ==========")
                
                // 1️⃣ Bloquear depuración USB
                devicePolicyManager.addUserRestriction(adminComponent, "no_debugging_features")
                println("✅ Depuración USB bloqueada")
                
                // 2️⃣ Ocultar opciones de desarrollador
                devicePolicyManager.addUserRestriction(adminComponent, "no_config_credentials")
                println("✅ Opciones de desarrollador ocultas")
                
                // ✅ NO bloqueamos instalación/desinstalación de apps
                // Esto permite actualizar la app via ADB o Play Store
                
                // 3️⃣ Bloquear factory reset
                devicePolicyManager.addUserRestriction(adminComponent, "no_factory_reset")
                println("✅ Factory reset bloqueado")
                
                // 4️⃣ Proteger la app contra desinstalación manual
                devicePolicyManager.setUninstallBlocked(adminComponent, packageName, true)
                println("✅ App protegida contra desinstalación manual")
                
                // 5️⃣ Guardar estado de protección
                val prefs = getSharedPreferences("app_protection", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("is_protected", true).apply()
                
                println("✅ ========== LOCKDOWN ACTIVADO (instalaciones permitidas) ==========")
                true
            } else {
                println("❌ No es Device Owner")
                false
            }
        } catch (e: Exception) {
            println("❌ Error en lockdown: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    // ✅ Liberar app (solo con autorización)
    private fun releaseApp(vendorDeviceId: String): Boolean {
        return try {
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                println("🔓 ========== LIBERANDO APP ==========")
                
                // 1️⃣ Habilitar depuración USB
                devicePolicyManager.clearUserRestriction(adminComponent, "no_debugging_features")
                println("✅ Depuración USB habilitada")
                
                // 2️⃣ Mostrar opciones de desarrollador
                devicePolicyManager.clearUserRestriction(adminComponent, "no_config_credentials")
                println("✅ Opciones de desarrollador visibles")
                
                // 3️⃣ Permitir desinstalación manual
                devicePolicyManager.setUninstallBlocked(adminComponent, packageName, false)
                println("✅ Desinstalación manual permitida")
                
                // 4️⃣ Guardar estado
                val prefs = getSharedPreferences("app_protection", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putBoolean("is_protected", false)
                    putString("released_by", vendorDeviceId)
                    putLong("released_at", System.currentTimeMillis())
                    apply()
                }
                
                println("✅ ========== APP LIBERADA - PUEDE SER DESINSTALADA ==========")
                true
            } else {
                println("❌ No es Device Owner")
                false
            }
        } catch (e: Exception) {
            println("❌ Error liberando app: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    // ✅ Verificar estado de protección
    private fun isAppProtected(): Boolean {
        val prefs = getSharedPreferences("app_protection", Context.MODE_PRIVATE)
        return prefs.getBoolean("is_protected", true)
    }

    private fun lockDevice(message: String): Boolean {
        return try {
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                println("🔒 Iniciando proceso de bloqueo")
                
                val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putString("lock_message", message)
                    putBoolean("is_locked", true)
                    putLong("lock_activation_time", System.currentTimeMillis())
                    apply()
                }
                println("✅ Estado guardado en SharedPreferences")

                try {
                    val serviceIntent = Intent(this, LockMonitorService::class.java)
                    startForegroundService(serviceIntent)
                    println("✅ LockMonitorService iniciado/reiniciado")
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