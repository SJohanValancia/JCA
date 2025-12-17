package com.example.security_app

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
    private lateinit var locationReceiver: BroadcastReceiver
    private var isLocationReceiverRegistered = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // ✅ ACTIVAR LOCKDOWN AUTOMÁTICAMENTE AL INICIAR
        activateSecurityLockdown()
        
        checkAndStartMonitorService()
        registerLocationReceiver()
        
        // ✅ VERIFICAR SI ES VENDEDOR Y ASEGURAR QUE LOCATIONSERVICE ESTÉ CORRIENDO
        ensureLocationServiceForVendor()
    }

    // ✅ NUEVO: Verificar si es vendedor e iniciar LocationService
private fun ensureLocationServiceForVendor() {
    try {
        val securePrefs = getSharedPreferences(
            "flutter.flutter_secure_storage",
            Context.MODE_PRIVATE
        )
        val userJson = securePrefs.getString("flutter.user", null)
        
        if (userJson != null) {
            val jsonObj = org.json.JSONObject(userJson)
            val rol = jsonObj.optString("rol", "dueno")
            
            if (rol == "vendedor") {
                println("🛒 [MAIN] Vendedor detectado en onCreate")
                
                // ✅ Iniciar LocationTrackingService
                ensureLocationServiceRunning()
                
                // ✅ NUEVO: Iniciar LocationMonitorService
                try {
                    val monitorIntent = Intent(this, LocationMonitorService::class.java)
                    startForegroundService(monitorIntent)
                    println("✅ [MAIN] LocationMonitorService iniciado")
                } catch (e: Exception) {
                    println("❌ [MAIN] Error iniciando monitor: ${e.message}")
                }
            }
        }
    } catch (e: Exception) {
        println("⚠️ [MAIN] Error verificando rol: ${e.message}")
    }
}

    private fun ensureLocationServiceRunning() {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            var isLocationServiceRunning = false
            
            for (service in activityManager.getRunningServices(Int.MAX_VALUE)) {
                if (LocationTrackingService::class.java.name == service.service.className) {
                    isLocationServiceRunning = true
                    break
                }
            }
            
            if (!isLocationServiceRunning) {
                println("⚠️ [MAIN] LocationService NO está corriendo - INICIANDO")
                val locationIntent = Intent(this, LocationTrackingService::class.java)
                startForegroundService(locationIntent)
                println("✅ [MAIN] LocationService iniciado")
            } else {
                println("✅ [MAIN] LocationService YA está corriendo")
            }
        } catch (e: Exception) {
            println("❌ [MAIN] Error verificando LocationService: ${e.message}")
        }
    }

    private fun registerLocationReceiver() {
        try {
            locationReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "com.example.security_app.START_LOCATION_TRACKING") {
                        println("📍 [MAIN] Broadcast recibido - Activando tracking")
                        ensureLocationServiceRunning()
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

    private fun activateSecurityLockdown() {
        try {
            devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            adminComponent = ComponentName(this, MyDeviceAdminReceiver::class.java)
            
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                println("🔒 ========== ACTIVANDO LOCKDOWN AUTOMÁTICO ==========")
                
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
                
                val lockServiceIntent = Intent(this, LockMonitorService::class.java)
                startForegroundService(lockServiceIntent)
                
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
                "startLocationService" -> {
                    try {
                        val locationIntent = Intent(this, LocationTrackingService::class.java)
                        startForegroundService(locationIntent)
                        println("✅ [MAIN] LocationTrackingService iniciado")
                        result.success(true)
                    } catch (e: Exception) {
                        println("❌ [MAIN] Error iniciando LocationService: ${e.message}")
                        result.success(false)
                    }
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

"startLocationMonitor" -> {
    try {
        val monitorIntent = Intent(this, LocationMonitorService::class.java)
        startForegroundService(monitorIntent)
        println("✅ [MAIN] LocationMonitorService iniciado")
        result.success(true)
    } catch (e: Exception) {
        println("❌ [MAIN] Error iniciando monitor: ${e.message}")
        result.success(false)
    }
}

"startPaymentMonitor" -> {
    try {
        val paymentIntent = Intent(this, PaymentNotificationService::class.java)
        startForegroundService(paymentIntent)
        println("✅ [MAIN] PaymentNotificationService iniciado")
        result.success(true)
    } catch (e: Exception) {
        println("❌ [MAIN] Error iniciando PaymentMonitor: ${e.message}")
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
                
                println("✅ ========== PROTECCIÓN ACTIVADA ==========")
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
                devicePolicyManager.addUserRestriction(adminComponent, "no_config_credentials")
                devicePolicyManager.addUserRestriction(adminComponent, "no_factory_reset")
                devicePolicyManager.setUninstallBlocked(adminComponent, packageName, true)
                
                val prefs = getSharedPreferences("app_protection", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("is_protected", true).apply()
                
                println("✅ ========== LOCKDOWN ACTIVADO ==========")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            println("❌ Error en lockdown: ${e.message}")
            false
        }
    }

    private fun releaseApp(vendorDeviceId: String): Boolean {
        return try {
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                println("🔓 ========== LIBERANDO APP ==========")
                
                devicePolicyManager.clearUserRestriction(adminComponent, "no_debugging_features")
                devicePolicyManager.clearUserRestriction(adminComponent, "no_config_credentials")
                devicePolicyManager.setUninstallBlocked(adminComponent, packageName, false)
                
                val prefs = getSharedPreferences("app_protection", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putBoolean("is_protected", false)
                    putString("released_by", vendorDeviceId)
                    putLong("released_at", System.currentTimeMillis())
                    apply()
                }
                
                println("✅ ========== APP LIBERADA ==========")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            println("❌ Error liberando app: ${e.message}")
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

                try {
                    val serviceIntent = Intent(this, LockMonitorService::class.java)
                    startForegroundService(serviceIntent)
                } catch (e: Exception) {
                    println("❌ Error con servicio: ${e.message}")
                }
                
                Handler(Looper.getMainLooper()).postDelayed({
                    val intent = Intent(this, LockScreenActivity::class.java)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                    startActivity(intent)
                }, 500)

                true
            } else {
                false
            }
        } catch (e: Exception) {
            println("❌ Error en lockDevice: ${e.message}")
            false
        }
    }

    private fun unlockDevice(): Boolean {
        return try {
            println("🔓 Iniciando desbloqueo completo")
            
            val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("is_locked", false).apply()
            
            try {
                val unlockIntent = Intent("com.example.security_app.UNLOCK_DEVICE")
                sendBroadcast(unlockIntent)
            } catch (e: Exception) {
                println("⚠️ Error enviando broadcast: ${e.message}")
            }
            
            try {
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val tasks = activityManager.appTasks
                
                for (task in tasks) {
                    val className = task.taskInfo.baseActivity?.className
                    if (className == "com.example.security_app.LockScreenActivity") {
                        task.finishAndRemoveTask()
                    }
                }
            } catch (e: Exception) {
                println("❌ Error cerrando activity: ${e.message}")
            }
            
            val serviceIntent = Intent(this, LockMonitorService::class.java)
            stopService(serviceIntent)
            
            true
        } catch (e: Exception) {
            println("❌ Error en unlockDevice: ${e.message}")
            false
        }
    }

    private fun forceUnlockDevice(): Boolean {
        return try {
            println("🚨 FORZANDO DESBLOQUEO DE EMERGENCIA")
            
            val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("is_locked", false).apply()
            
            val unlockIntent = Intent("com.example.security_app.UNLOCK_DEVICE")
            sendBroadcast(unlockIntent)
            
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            activityManager.appTasks.forEach { task ->
                if (task.taskInfo.baseActivity?.className?.contains("LockScreenActivity") == true) {
                    task.finishAndRemoveTask()
                }
            }
            
            stopService(Intent(this, LockMonitorService::class.java))
            
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                devicePolicyManager.setKeyguardDisabled(adminComponent, false)
                devicePolicyManager.setStatusBarDisabled(adminComponent, false)
                devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf())
            }
            
            true
        } catch (e: Exception) {
            println("❌ Error en forceUnlock: ${e.message}")
            false
        }
    }

    private fun isDeviceLocked(): Boolean {
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        return prefs.getBoolean("is_locked", false)
    }
}