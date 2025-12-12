package com.example.security_app

import android.app.Activity
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.*

class LockScreenActivity : Activity() {
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var adminComponent: ComponentName
    private lateinit var handler: android.os.Handler
    private lateinit var focusRunnable: Runnable

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        setupFullscreen()
        setContentView(R.layout.activity_lock_screen)
        
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponent = ComponentName(this, MyDeviceAdminReceiver::class.java)

        // Deshabilitar keyguard
        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
            devicePolicyManager.setKeyguardDisabled(adminComponent, true)
            devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf(packageName))
        }

        // Cargar mensaje
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        val message = prefs.getString("lock_message", "Dispositivo bloqueado")

        findViewById<TextView>(R.id.lockMessage).text = message
        
        val dateFormat = SimpleDateFormat("dd 'de' MMMM 'de' yyyy", Locale("es", "ES"))
        val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
        val now = Date()
        
        findViewById<TextView>(R.id.lockDate).text = dateFormat.format(now)
        findViewById<TextView>(R.id.lockTime).text = timeFormat.format(now)

        // Iniciar modo Lock Task (kiosk mode)
        startLockTask()

        // Verificación periódica de desbloqueo
        startUnlockCheck()
        
        // Forzar foco constantemente
        startForceFocus()
    }

    private fun setupFullscreen() {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        )

        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_FULLSCREEN
            or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        )
    }

    private fun startForceFocus() {
        handler = android.os.Handler(mainLooper)
        focusRunnable = object : Runnable {
            override fun run() {
                // Mover esta actividad al frente constantemente
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                activityManager.moveTaskToFront(taskId, 0)
                handler.postDelayed(this, 500) // Cada 0.5 segundos
            }
        }
        handler.post(focusRunnable)
    }

    private fun startUnlockCheck() {
        val unlockHandler = android.os.Handler(mainLooper)
        val runnable = object : Runnable {
            override fun run() {
                val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
                val isLocked = prefs.getBoolean("is_locked", false)
                
                if (!isLocked) {
                    // Dispositivo desbloqueado
                    stopLockTask()
                    if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                        devicePolicyManager.setKeyguardDisabled(adminComponent, false)
                        devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf())
                    }
                    handler.removeCallbacks(focusRunnable)
                    finish()
                } else {
                    unlockHandler.postDelayed(this, 3000)
                }
            }
        }
        unlockHandler.postDelayed(runnable, 3000)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Bloquear TODOS los botones
        return true
    }

    override fun onBackPressed() {
        // No hacer nada
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            setupFullscreen()
        } else {
            // Si pierde el foco, recuperarlo inmediatamente
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            activityManager.moveTaskToFront(taskId, 0)
        }
    }

    override fun onPause() {
        super.onPause()
        // Forzar regreso inmediato
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        activityManager.moveTaskToFront(taskId, 0)
    }

    override fun onStop() {
        super.onStop()
        // Reiniciar la actividad si se detiene
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        val isLocked = prefs.getBoolean("is_locked", false)
        
        if (isLocked) {
            val intent = Intent(this, LockScreenActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            startActivity(intent)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(focusRunnable)
    }
}