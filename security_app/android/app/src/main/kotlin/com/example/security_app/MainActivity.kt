package com.example.security_app

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.security_app/device_owner"
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var adminComponent: ComponentName

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponent = ComponentName(this, MyDeviceAdminReceiver::class.java)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
                    result.success(isLocked)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun lockDevice(message: String): Boolean {
        return try {
            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                // Guardar mensaje en SharedPreferences
                val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putString("lock_message", message)
                    putBoolean("is_locked", true)
                    apply()
                }

                // Iniciar LockScreenActivity
                val intent = Intent(this, LockScreenActivity::class.java)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                startActivity(intent)

                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun unlockDevice(): Boolean {
        return try {
            val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putBoolean("is_locked", false)
                apply()
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun isDeviceLocked(): Boolean {
        val prefs = getSharedPreferences("lock_prefs", Context.MODE_PRIVATE)
        return prefs.getBoolean("is_locked", false)
    }
}