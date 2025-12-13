package com.example.security_app

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Handler
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.*
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

class LockScreenActivity : Activity() {
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var adminComponent: ComponentName
    private lateinit var handler: Handler
    private lateinit var unlockReceiver: BroadcastReceiver
    private var isReceiverRegistered = false
    
    // ✅ NUEVO: Cliente HTTP para consultar backend
    private val client = OkHttpClient()
    private val baseUrl = "https://jca-labd.onrender.com"
    private lateinit var backendCheckRunnable: Runnable

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        println("🔒 LockScreenActivity onCreate")
        
        setupFullscreen()
        setContentView(R.layout.activity_lock_screen)
        
        window.addFlags(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponent = ComponentName(this, MyDeviceAdminReceiver::class.java)

        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
            devicePolicyManager.setKeyguardDisabled(adminComponent, true)
            devicePolicyManager.setStatusBarDisabled(adminComponent, true)
            devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf(packageName))
            println("✅ Device Owner configurado")
        }

        try {
            val serviceIntent = Intent(this, LockMonitorService::class.java)
            startForegroundService(serviceIntent)
            println("✅ LockMonitorService iniciado")
        } catch (e: Exception) {
            println("❌ Error iniciando servicio: ${e.message}")
        }

        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        val message = prefs.getString("lock_message", "Dispositivo bloqueado")

        findViewById<TextView>(R.id.lockMessage).text = message
        
        val dateFormat = SimpleDateFormat("dd 'de' MMMM 'de' yyyy", Locale("es", "ES"))
        val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
        val now = Date()
        
        findViewById<TextView>(R.id.lockDate).text = dateFormat.format(now)
        findViewById<TextView>(R.id.lockTime).text = timeFormat.format(now)

        startLockTask()
        println("✅ Lock Task Mode activado")

        registerUnlockReceiver()
        
        // ✅ NUEVO: Iniciar verificación constante al backend
        startBackendChecker()
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

    // ✅ NUEVO: Verificar backend cada 5 segundos
    private fun startBackendChecker() {
        handler = Handler(mainLooper)
        backendCheckRunnable = object : Runnable {
            override fun run() {
                println("🌐 [LOCKSCREEN] Verificando estado en backend...")
                checkBackendStatus()
                handler.postDelayed(this, 5000) // ← CADA 5 SEGUNDOS
            }
        }
        handler.post(backendCheckRunnable)
        println("✅ Backend checker iniciado (cada 5 segundos)")
    }

    // ✅ NUEVO: Consultar al backend si debe desbloquearse
    private fun checkBackendStatus() {
        Thread {
            try {
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
                    .get()
                    .build()

                client.newCall(request).execute().use { response ->
                    val statusCode = response.code
                    println("📡 [LOCKSCREEN] Status Code: $statusCode")

                    if (!response.isSuccessful) {
                        println("❌ [LOCKSCREEN] Backend no respondió correctamente")
                        return@use
                    }

                    val body = response.body?.string() ?: "{}"
                    println("📦 [LOCKSCREEN] Response: $body")

                    val json = JSONObject(body)
                    val backendLocked = json.optBoolean("isLocked", true)
                    val message = json.optString("lockMessage", "Dispositivo bloqueado")

                    println("🔍 [LOCKSCREEN] Backend dice isLocked = $backendLocked")

                    if (backendLocked) {
                        println("🔒 [LOCKSCREEN] Aún bloqueado, mantener pantalla")
                    } else {
                        println("🔓 [LOCKSCREEN] ¡DESBLOQUEADO! Iniciando cierre...")
                        
                        // ✅ Actualizar SharedPreferences
                        runOnUiThread {
                            val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
                            prefs.edit().putBoolean("is_locked", false).apply()
                            println("✅ [LOCKSCREEN] SharedPreferences actualizado")
                            
                            // ✅ Cerrar pantalla de bloqueo
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
                        println("📡 [LOCKSCREEN] Broadcast recibido")
                        finishUnlock()
                    }
                }
            }
            
            val filter = IntentFilter("com.example.security_app.UNLOCK_DEVICE")
            registerReceiver(unlockReceiver, filter)
            isReceiverRegistered = true
            println("✅ BroadcastReceiver registrado")
        } catch (e: Exception) {
            println("❌ Error registrando receiver: ${e.message}")
        }
    }

    private fun finishUnlock() {
        println("🔓 [LOCKSCREEN] ========== EJECUTANDO DESBLOQUEO COMPLETO ==========")
        
        try {
            // ✅ 1. Detener verificación de backend
            try {
                handler.removeCallbacksAndMessages(null)
                println("✅ [LOCKSCREEN] Handler detenido")
            } catch (e: Exception) {
                println("⚠️ [LOCKSCREEN] Error deteniendo handler: ${e.message}")
            }

            // ✅ 2. Detener Lock Task Mode
            try {
                stopLockTask()
                println("✅ [LOCKSCREEN] Lock Task detenido")
            } catch (e: Exception) {
                println("⚠️ [LOCKSCREEN] Error deteniendo Lock Task: ${e.message}")
            }
            
            // ✅ 3. Restaurar Device Owner
            try {
                if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                    devicePolicyManager.setKeyguardDisabled(adminComponent, false)
                    devicePolicyManager.setStatusBarDisabled(adminComponent, false)
                    devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf())
                    println("✅ [LOCKSCREEN] Device Owner restaurado")
                }
            } catch (e: Exception) {
                println("⚠️ [LOCKSCREEN] Error restaurando Device Owner: ${e.message}")
            }
            
            // ✅ 4. Desregistrar broadcast receiver
            if (isReceiverRegistered) {
                try {
                    unregisterReceiver(unlockReceiver)
                    isReceiverRegistered = false
                    println("✅ [LOCKSCREEN] Receiver desregistrado")
                } catch (e: Exception) {
                    println("⚠️ [LOCKSCREEN] Error desregistrando: ${e.message}")
                }
            }
            
            // ✅ 5. Detener servicio de monitoreo
            try {
                val serviceIntent = Intent(this, LockMonitorService::class.java)
                stopService(serviceIntent)
                println("✅ [LOCKSCREEN] Servicio detenido")
            } catch (e: Exception) {
                println("⚠️ [LOCKSCREEN] Error deteniendo servicio: ${e.message}")
            }
            
            // ✅ 6. Cerrar activity
            finishAndRemoveTask()
            println("✅ [LOCKSCREEN] ========== DESBLOQUEO COMPLETO EXITOSO ==========")
            
        } catch (e: Exception) {
            println("❌ [LOCKSCREEN] Error CRÍTICO en desbloqueo: ${e.message}")
            e.printStackTrace()
            
            try {
                finish()
            } catch (ex: Exception) {
                println("❌ [LOCKSCREEN] No se pudo cerrar: ${ex.message}")
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean = true
    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean = true
    override fun dispatchKeyEvent(event: KeyEvent?): Boolean = true
    override fun onBackPressed() {}

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            setupFullscreen()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        println("🔒 [LOCKSCREEN] onDestroy")
        
        try {
            handler.removeCallbacksAndMessages(null)
        } catch (e: Exception) {
            println("⚠️ [LOCKSCREEN] Error limpiando: ${e.message}")
        }
    }
}