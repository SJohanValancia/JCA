package com.example.security_app

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.app.ActivityManager 
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.*
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class LockScreenActivity : Activity() {
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var adminComponent: ComponentName
    private lateinit var handler: Handler
    private lateinit var unlockReceiver: BroadcastReceiver
    private var isReceiverRegistered = false
    
    // ✅ Cliente HTTP configurado correctamente
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()
    private val baseUrl = "https://jca-labd.onrender.com"
    private lateinit var backendCheckRunnable: Runnable
    private var checkCount = 0

    // ✅ NUEVO: Referencia al TextView de estado
    private lateinit var lockStatus: TextView
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    
    println("🔒 ========== LockScreenActivity onCreate ==========")
    
    setupFullscreen()
    ensureServiceIsRunning()
    
    // ✅ NUEVO: Asegurar que el servicio de ubicación esté corriendo
    try {
        val locationIntent = Intent(this, LocationTrackingService::class.java)
        startForegroundService(locationIntent)
        println("✅ [LOCK] Servicio de ubicación verificado/iniciado")
    } catch (e: Exception) {
        println("❌ [LOCK] Error con servicio de ubicación: ${e.message}")
    }
    
    setContentView(R.layout.activity_lock_screen)
        
        window.addFlags(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponent = ComponentName(this, MyDeviceAdminReceiver::class.java)

        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
            devicePolicyManager.setKeyguardDisabled(adminComponent, true)
            devicePolicyManager.setStatusBarDisabled(adminComponent, true)
            devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf(packageName))
            println("✅ [LOCK] Device Owner configurado")
        }

        try {
            val serviceIntent = Intent(this, LockMonitorService::class.java)
            startForegroundService(serviceIntent)
            println("✅ [LOCK] LockMonitorService iniciado")
        } catch (e: Exception) {
            println("❌ [LOCK] Error iniciando servicio: ${e.message}")
        }

        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        val message = prefs.getString("lock_message", "Dispositivo bloqueado")

        findViewById<TextView>(R.id.lockMessage).text = message
        
        // ✅ NUEVO: Leer timestamp de activación y formatear
        val activationTime = prefs.getLong("lock_activation_time", System.currentTimeMillis())
        val activationDate = Date(activationTime)
        
        val dateFormat = SimpleDateFormat("dd 'de' MMMM 'de' yyyy", Locale("es", "ES"))
        val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
        
        findViewById<TextView>(R.id.lockDate).text = dateFormat.format(activationDate)
        findViewById<TextView>(R.id.lockTime).text = timeFormat.format(activationDate)

        // ✅ NUEVO: Inicializar TextView de estado y actualizar inicialmente
        lockStatus = findViewById<TextView>(R.id.lockStatus)
        updateStatus()

        startLockTask()
        println("✅ [LOCK] Lock Task Mode activado")

        registerUnlockReceiver()
        
        // ✅ Iniciar verificación al backend
        startBackendChecker()
        
        println("✅ ========== LockScreenActivity completamente inicializado ==========")
    }

    private fun ensureServiceIsRunning() {
    try {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        var isServiceRunning = false
        
        for (service in activityManager.getRunningServices(Int.MAX_VALUE)) {
            if (LockMonitorService::class.java.name == service.service.className) {
                isServiceRunning = true
                break
            }
        }
        
        if (!isServiceRunning) {
            println("⚠️ [LOCK] Servicio NO está corriendo - REINICIANDO")
            val serviceIntent = Intent(this, LockMonitorService::class.java)
            startForegroundService(serviceIntent)
            println("✅ [LOCK] Servicio reiniciado")
        } else {
            println("✅ [LOCK] Servicio YA está corriendo")
        }
    } catch (e: Exception) {
        println("❌ [LOCK] Error verificando servicio: ${e.message}")
    }
}

    private fun setupFullscreen() {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
        
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_LOW_PROFILE
        )
    }

    // ✅ NUEVO: Método para actualizar el estado en tiempo real
    private fun updateStatus() {
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        val isLocked = prefs.getBoolean("is_locked", false)
        lockStatus.text = if (isLocked) "Bloqueado: Sí" else "Bloqueado: No"
        println("🔄 [LOCK] Estado actualizado: ${lockStatus.text}")
    }

    // ✅ Iniciar verificación constante al backend
    private fun startBackendChecker() {
        handler = Handler(Looper.getMainLooper())
        backendCheckRunnable = object : Runnable {
            override fun run() {
                checkCount++
                println("🌐 [LOCK #$checkCount] ===== VERIFICANDO BACKEND =====")
                checkBackendStatus()
                
                // ✅ NUEVO: Actualizar estado después de cada verificación
                runOnUiThread { updateStatus() }
                
                handler.postDelayed(this, 5000) // ← CADA 5 SEGUNDOS
            }
        }
        
        // ✅ Primera verificación inmediata
        handler.post(backendCheckRunnable)
    }

private fun checkBackendStatus() {
    Thread {
        try {
            // ✅ VERIFICAR si es alerta ADB
            val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
            val isAdbAlert = prefs.getBoolean("is_adb_alert", false)
            
            if (isAdbAlert) {
                println("🚨 [LOCK] Alerta ADB activa - No consultar backend")
                return@Thread
            }
            
            val securePrefs = getSharedPreferences(
                "flutter.flutter_secure_storage",
                Context.MODE_PRIVATE
            )
            val token = securePrefs.getString("flutter.token", null)

            if (token == null) {
                println("⚠️ [LOCKSCREEN] Token no encontrado")
                return@Thread
            }

            println("🔑 [LOCKSCREEN] Token encontrado, consultando...")

            val request = Request.Builder()
                .url("$baseUrl/api/lock/check")
                .addHeader("Authorization", "Bearer $token")
                .build()

            val response = client.newCall(request).execute()

            println("📡 [LOCKSCREEN] Status: ${response.code}")

            if (response.isSuccessful) {
                val body = response.body?.string() ?: ""
                println("📦 [LOCKSCREEN] Response: $body")
                
                val json = JSONObject(body)
                val isLocked = json.getBoolean("isLocked")

                if (!isLocked) {
                    println("🔓 [LOCKSCREEN] Backend indica desbloqueo - procediendo...")
                    
                    runOnUiThread {
                        val localPrefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
                        localPrefs.edit().putBoolean("is_locked", false).apply()
                        println("✅ [LOCKSCREEN] SharedPreferences actualizado")
                        
                        finishUnlock()
                    }
                }
            }

        } catch (e: Exception) {
            println("❌ [LOCKSCREEN] Error consultando backend: ${e.message}")
            e.printStackTrace()
        }
    }.start()
}

    private fun registerUnlockReceiver() {
        try {
            unlockReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "com.example.security_app.UNLOCK_DEVICE") {
                        println("📡 [LOCK] ¡Broadcast de desbloqueo recibido!")
                        finishUnlock()
                    }
                }
            }
            
            val filter = IntentFilter("com.example.security_app.UNLOCK_DEVICE")
            registerReceiver(unlockReceiver, filter)
            isReceiverRegistered = true
            println("✅ [LOCK] BroadcastReceiver registrado")
        } catch (e: Exception) {
            println("❌ [LOCK] Error registrando receiver: ${e.message}")
        }
    }

    private fun finishUnlock() {
        println("🔓🔓🔓 [LOCK] ========== EJECUTANDO DESBLOQUEO COMPLETO ==========")
        
        try {
            // ✅ 1. Detener verificación de backend
            try {
                handler.removeCallbacksAndMessages(null)
                println("✅ [LOCK] Handler y verificaciones detenidas")
            } catch (e: Exception) {
                println("⚠️ [LOCK] Error deteniendo handler: ${e.message}")
            }

            // ✅ 2. Detener Lock Task Mode
            try {
                stopLockTask()
                println("✅ [LOCK] Lock Task Mode detenido")
            } catch (e: Exception) {
                println("⚠️ [LOCK] Error deteniendo Lock Task: ${e.message}")
            }
            
            // ✅ 3. Restaurar Device Owner
            try {
                if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                    devicePolicyManager.setKeyguardDisabled(adminComponent, false)
                    devicePolicyManager.setStatusBarDisabled(adminComponent, false)
                    devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf())
                    println("✅ [LOCK] Device Owner restaurado a valores normales")
                }
            } catch (e: Exception) {
                println("⚠️ [LOCK] Error restaurando Device Owner: ${e.message}")
            }
            
            // ✅ 4. Desregistrar broadcast receiver
            if (isReceiverRegistered) {
                try {
                    unregisterReceiver(unlockReceiver)
                    isReceiverRegistered = false
                    println("✅ [LOCK] BroadcastReceiver desregistrado")
                } catch (e: Exception) {
                    println("⚠️ [LOCK] Error desregistrando receiver: ${e.message}")
                }
            }
            
            // ✅ 5. NO detener el servicio aquí, déjalo corriendo
            println("ℹ️ [LOCK] Servicio de monitoreo permanece activo")
            
            // ✅ 6. Cerrar activity
            println("🔓 [LOCK] Cerrando LockScreenActivity...")
            finishAndRemoveTask()
            println("✅✅✅ [LOCK] ========== DESBLOQUEO COMPLETO EXITOSO ==========")
            
        } catch (e: Exception) {
            println("❌❌❌ [LOCK] Error CRÍTICO en desbloqueo: ${e.message}")
            e.printStackTrace()
            
            try {
                finish()
            } catch (ex: Exception) {
                println("❌ [LOCK] No se pudo cerrar activity: ${ex.message}")
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        println("🚫 [LOCK] onKeyDown bloqueado: $keyCode")
        return true
    }
    
    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        println("🚫 [LOCK] onKeyUp bloqueado: $keyCode")
        return true
    }
    
    override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
        println("🚫 [LOCK] dispatchKeyEvent bloqueado")
        return true
    }
    
    override fun onBackPressed() {
        println("🚫 [LOCK] Botón atrás bloqueado")
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        println("👁️ [LOCK] Focus cambió: $hasFocus")
        if (hasFocus) {
            setupFullscreen()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        println("💀 [LOCK] onDestroy - Activity siendo destruida")
        
        try {
            handler.removeCallbacksAndMessages(null)
        } catch (e: Exception) {
            println("⚠️ [LOCK] Error en cleanup: ${e.message}")
        }
    }

    override fun onPause() {
        super.onPause()
        println("⏸️ [LOCK] onPause")
    }

    override fun onResume() {
        super.onResume()
        println("▶️ [LOCK] onResume")
        setupFullscreen()
    }
}