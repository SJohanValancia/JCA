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

class LockScreenActivity : Activity() {
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var adminComponent: ComponentName
    private lateinit var handler: Handler
    private lateinit var unlockReceiver: BroadcastReceiver
    private var isReceiverRegistered = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        println("🔒 LockScreenActivity onCreate")
        
        setupFullscreen()
        setContentView(R.layout.activity_lock_screen)
        
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
        startLockWatcher()
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

    private fun isLocked(): Boolean {
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        val locked = prefs.getBoolean("is_locked", false)
        println("🔍 isLocked check: $locked")
        return locked
    }

    private fun startLockWatcher() {
        handler = Handler(mainLooper)
        handler.post(object : Runnable {
            override fun run() {
                try {
                    if (!isLocked()) {
                        println("✅ Estado cambió a desbloqueado - cerrando")
                        finishUnlock()
                        return
                    }
                    handler.postDelayed(this, 1000)
                } catch (e: Exception) {
                    println("❌ Error en watcher: ${e.message}")
                    handler.removeCallbacksAndMessages(null)
                }
            }
        })
        println("✅ Lock watcher iniciado")
    }

    private fun registerUnlockReceiver() {
        try {
            unlockReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "com.example.security_app.UNLOCK_DEVICE") {
                        println("📡 Broadcast recibido")
                        if (!isLocked()) {
                            finishUnlock()
                        }
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
        println("🔓 Ejecutando desbloqueo completo")
        
        try {
            stopLockTask()
            println("✅ Lock Task detenido")
            
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                devicePolicyManager.setKeyguardDisabled(adminComponent, false)
                devicePolicyManager.setStatusBarDisabled(adminComponent, false)
                devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf())
                println("✅ Device Owner restaurado")
            }
            
            if (isReceiverRegistered) {
                try {
                    unregisterReceiver(unlockReceiver)
                    isReceiverRegistered = false
                    println("✅ Receiver desregistrado")
                } catch (e: Exception) {
                    println("⚠️ Error desregistrando: ${e.message}")
                }
            }
            
            try {
                handler.removeCallbacksAndMessages(null)
                println("✅ Handler detenido")
            } catch (e: Exception) {
                println("⚠️ Error deteniendo handler: ${e.message}")
            }
            
            try {
                val serviceIntent = Intent(this, LockMonitorService::class.java)
                stopService(serviceIntent)
                println("✅ Servicio detenido")
            } catch (e: Exception) {
                println("⚠️ Error deteniendo servicio: ${e.message}")
            }
            
            finishAndRemoveTask()
            println("✅ Activity cerrada - desbloqueo completo")
            
        } catch (e: Exception) {
            println("❌ Error en desbloqueo: ${e.message}")
            e.printStackTrace()
            
            try {
                finish()
            } catch (ex: Exception) {
                println("❌ No se pudo cerrar: ${ex.message}")
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
        println("🔒 LockScreenActivity onDestroy")
        
        try {
            handler.removeCallbacksAndMessages(null)
        } catch (e: Exception) {
            println("⚠️ Error limpiando: ${e.message}")
        }
    }
}