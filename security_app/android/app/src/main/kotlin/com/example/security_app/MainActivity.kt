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
        private lateinit var locationReceiver: BroadcastReceiver // ✅ NUEVO
    private var isLocationReceiverRegistered = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // ✅ ACTIVAR LOCKDOWN AUTOMÁTICAMENTE AL INICIAR
        activateSecurityLockdown()
        
        checkAndStartMonitorService()

        registerLocationReceiver() 
    }

      private fun registerLocationReceiver() {
        try {
            locationReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "com.example.security_app.START_LOCATION_TRACKING") {
                        println("📍 [MAIN] Broadcast recibido - Activando tracking")
                        activateLocationTracking()
                    }
                }
            }
            
            val filter = IntentFilter("com.example.security_app.START_LOCATION_TRACKING")
            registerReceiver(locationReceiver, filter)
            isLocationReceiverRegistered = true
            println("✅ [MAIN] Location receiver registrado")
        } catch (e: Exception) {
            println("❌ [MAIN] Error registrando location receiver: ${e.message}")
        }
    }

    // ✅ NUEVO: Activar tracking desde Flutter
    private fun activateLocationTracking() {
        try {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod(
                    "activateLocationTracking",
                    null,
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            println("✅ [MAIN] Location tracking activado en Flutter")
                        }
                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                            println("❌ [MAIN] Error activando tracking: $errorMessage")
                        }
                        override fun notImplemented() {
                            println("⚠️ [MAIN] Método no implementado en Flutter")
                        }
                    }
                )
            }
        } catch (e: Exception) {
            println("❌ [MAIN] Error invocando método Flutter: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isLocationReceiverRegistered) {
            try {
                unregisterReceiver(locationReceiver)
            } catch (e: Exception) {
                println("⚠️ [MAIN] Error desregistrando receiver: ${e.message}")
            }
        }
    }

    // ✅ Activar lockdown de seguridad automáticamente
    private fun activateSecurityLockdown() {
        try {
            devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            adminComponent = ComponentName(this, MyDeviceAdminReceiver::class.java)
            
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                println("🔒 ========== ACTIVANDO LOCKDOWN AUTOMÁTICO ==========")
                
                // 1️⃣ Bloquear depuración USB
                devicePolicyManager.addUserRestriction(adminComponent, "no_debugging_features")
                println("✅ Depuración USB bloqueada")
                
                // 2️⃣ Ocultar opciones de desarrollador
                devicePolicyManager.addUserRestriction(adminComponent, "no_config_credentials")
                println("✅ Opciones de desarrollador ocultas")
                
                // 3️⃣ Bloquear factory reset
                devicePolicyManager.addUserRestriction(adminComponent, "no_factory_reset")
                println("✅ Factory reset bloqueado")
                
                // 4️⃣ Proteger la app contra desinstalación manual
                devicePolicyManager.setUninstallBlocked(adminComponent, packageName, true)
                println("✅ App protegida contra desinstalación manual")
                
                // 5️⃣ Guardar estado de protección
                val prefs = getSharedPreferences("app_protection", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("is_protected", true).apply()
                
                println("✅ ========== LOCKDOWN AUTOMÁTICO ACTIVADO ==========")
            } else {
                println("ℹ️ No es Device Owner - Lockdown no aplicado")
            }
        } catch (e: Exception) {
            println("❌ Error activando lockdown automático: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun checkAndStartMonitorService() {
        try {
            val securePrefs = getSharedPreferences(
                "flutter.flutter_secure_storage",
                Context.MODE_PRIVATE
            )
            val token = securePrefs.getString("flutter.token", null)
            
            if (token != null) {
                println("✅ Token encontrado - Iniciando servicios")
                
                // Iniciar LockMonitorService
                val lockServiceIntent = Intent(this, LockMonitorService::class.java)
                startForegroundService(lockServiceIntent)
                
                // Iniciar AdbDetectionService
                val adbServiceIntent = Intent(this, AdbDetectionService::class.java)
                startForegroundService(adbServiceIntent)
                
                println("✅ Servicios iniciados")
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
    }

    private fun protectAppFromUninstall(): Boolean {
        return try {
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                println("🔒 ========== ACTIVANDO PROTECCIÓN CONTRA DESINSTALACIÓN ==========")
                
                devicePolicyManager.setUninstallBlocked(adminComponent, packageName, true)
                println("✅ App bloqueada contra desinstalación manual")
                
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

    private fun lockDownDevice(): Boolean {
        return try {
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                println("🔒 ========== ACTIVANDO LOCKDOWN ==========")
                
                devicePolicyManager.addUserRestriction(adminComponent, "no_debugging_features")
                println("✅ Depuración USB bloqueada")
                
                devicePolicyManager.addUserRestriction(adminComponent, "no_config_credentials")
                println("✅ Opciones de desarrollador ocultas")
                
                devicePolicyManager.addUserRestriction(adminComponent, "no_factory_reset")
                println("✅ Factory reset bloqueado")
                
                devicePolicyManager.setUninstallBlocked(adminComponent, packageName, true)
                println("✅ App protegida contra desinstalación manual")
                
                val prefs = getSharedPreferences("app_protection", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("is_protected", true).apply()
                
                println("✅ ========== LOCKDOWN ACTIVADO ==========")
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

    private fun releaseApp(vendorDeviceId: String): Boolean {
        return try {
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                println("🔓 ========== LIBERANDO APP ==========")
                
                devicePolicyManager.clearUserRestriction(adminComponent, "no_debugging_features")
                println("✅ Depuración USB habilitada")
                
                devicePolicyManager.clearUserRestriction(adminComponent, "no_config_credentials")
                println("✅ Opciones de desarrollador visibles")
                
                devicePolicyManager.setUninstallBlocked(adminComponent, packageName, false)
                println("✅ Desinstalación manual permitida")
                
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

                // ✅ Enviar broadcast para activar ubicación
                try {
                    val locationIntent = Intent("com.example.security_app.START_LOCATION_TRACKING")
                    sendBroadcast(locationIntent)
                    println("📍 Broadcast de ubicación enviado")
                } catch (e: Exception) {
                    println("⚠️ Error enviando broadcast: ${e.message}")
                }

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

    // ✅ SOLO UNA DEFINICIÓN de isDeviceLocked()
    private fun isDeviceLocked(): Boolean {
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        return prefs.getBoolean("is_locked", false)
    }
}