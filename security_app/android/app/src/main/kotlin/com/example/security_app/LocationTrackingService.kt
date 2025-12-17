package com.example.security_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class LocationTrackingService : Service() {
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private var wakeLock: PowerManager.WakeLock? = null
    
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()
    
    private val baseUrl = "https://jca-labd.onrender.com"

    companion object {
        private const val CHANNEL_ID = "location_tracking_channel"
        private const val NOTIFICATION_ID = 3
        var isRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        println("📍 [LOCATION] ========================================")
        println("📍 [LOCATION] LocationTrackingService onCreate")
        println("📍 [LOCATION] ========================================")
        
        // ✅ ADQUIRIR WAKELOCK PARA MANTENER CPU ACTIVA
        acquireWakeLock()
        
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        setupLocationCallback()
        startLocationUpdates()
        
        println("✅ [LOCATION] Servicio de ubicación COMPLETAMENTE OPERACIONAL")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        println("▶️ [LOCATION] onStartCommand - Reiniciando si es necesario")
        
        // ✅ Asegurar que WakeLock esté activo
        if (wakeLock?.isHeld != true) {
            acquireWakeLock()
        }
        
        // ✅ Reiniciar actualizaciones de ubicación si no están activas
        if (!isRunning) {
            isRunning = true
            startLocationUpdates()
        }
        
        return START_STICKY // ✅ CRÍTICO: Reiniciar automáticamente si se detiene
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ✅ ADQUIRIR WAKELOCK
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "SecurityApp::LocationTrackingWakeLock"
            )
            wakeLock?.acquire(10 * 60 * 60 * 1000L) // 10 horas
            println("✅ [LOCATION] WakeLock adquirido")
        } catch (e: Exception) {
            println("❌ [LOCATION] Error adquiriendo WakeLock: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Seguimiento de Ubicación",
                NotificationManager.IMPORTANCE_HIGH // ✅ CAMBIAR A HIGH
            ).apply {
                description = "Envía tu ubicación en tiempo real"
                setShowBadge(false)
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("📍 Ubicación Activa")
            .setContentText("Compartiendo ubicación en tiempo real")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_HIGH) // ✅ PRIORIDAD ALTA
            .setOngoing(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun setupLocationCallback() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    println("📍 [LOCATION] ==========================================")
                    println("📍 [LOCATION] Nueva ubicación recibida")
                    println("📍 [LOCATION] Lat: ${location.latitude}, Lon: ${location.longitude}")
                    println("📍 [LOCATION] Accuracy: ${location.accuracy}m")
                    println("📍 [LOCATION] ==========================================")
                    sendLocationToBackend(location)
                }
            }

            override fun onLocationAvailability(availability: LocationAvailability) {
                println("📍 [LOCATION] Disponibilidad: ${availability.isLocationAvailable}")
            }
        }
    }

    private fun startLocationUpdates() {
        // ✅ CONFIGURACIÓN AGRESIVA PARA MÁXIMA ACTUALIZACIÓN
        val locationRequest = LocationRequest.create().apply {
            interval = 10000 // 10 segundos
            fastestInterval = 5000 // 5 segundos
            priority = LocationRequest.PRIORITY_HIGH_ACCURACY
            maxWaitTime = 10000
        }

        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            try {
                fusedLocationClient.requestLocationUpdates(
                    locationRequest,
                    locationCallback,
                    Looper.getMainLooper() // ✅ Usar MainLooper
                )
                println("✅ [LOCATION] Actualizaciones de ubicación INICIADAS")
                
                // ✅ OBTENER UBICACIÓN INMEDIATA
                fusedLocationClient.lastLocation.addOnSuccessListener { location ->
                    if (location != null) {
                        println("📍 [LOCATION] Ubicación inicial obtenida")
                        sendLocationToBackend(location)
                    }
                }
            } catch (e: Exception) {
                println("❌ [LOCATION] Error iniciando actualizaciones: ${e.message}")
            }
        } else {
            println("❌ [LOCATION] Sin permisos de ubicación")
        }
    }

    private fun sendLocationToBackend(location: Location) {
        Thread {
            try {
                println("🌐 [LOCATION] ==========================================")
                println("📤 [LOCATION] ENVIANDO ubicación al backend...")
                
                val securePrefs = getSharedPreferences(
                    "flutter.flutter_secure_storage",
                    Context.MODE_PRIVATE
                )
                val token = securePrefs.getString("flutter.token", null)

                if (token == null) {
                    println("⚠️ [LOCATION] No hay token - ABORTANDO")
                    return@Thread
                }

                println("✅ [LOCATION] Token: ${token.substring(0, 20)}...")
                println("📍 [LOCATION] Lat: ${location.latitude}")
                println("📍 [LOCATION] Lon: ${location.longitude}")
                println("🎯 [LOCATION] Accuracy: ${location.accuracy}m")

                val json = JSONObject().apply {
                    put("latitude", location.latitude)
                    put("longitude", location.longitude)
                    put("accuracy", location.accuracy)
                    put("timestamp", System.currentTimeMillis())
                }

                val body = json.toString().toRequestBody("application/json".toMediaType())
                val url = "$baseUrl/api/link/location/update"

                val request = Request.Builder()
                    .url(url)
                    .addHeader("Authorization", "Bearer $token")
                    .addHeader("Content-Type", "application/json")
                    .post(body)
                    .build()

                println("📡 [LOCATION] Enviando request a: $url")
                val response = client.newCall(request).execute()

                println("📊 [LOCATION] Status Code: ${response.code}")
                
                if (response.isSuccessful) {
                    println("✅✅✅ [LOCATION] UBICACIÓN ENVIADA EXITOSAMENTE")
                    
                    // ✅ Actualizar notificación con última actualización
                    updateNotification("Última actualización: ${java.text.SimpleDateFormat("HH:mm:ss").format(java.util.Date())}")
                } else {
                    val errorBody = response.body?.string() ?: "Sin respuesta"
                    println("❌ [LOCATION] Error ${response.code}: $errorBody")
                }

                response.close()

            } catch (e: Exception) {
                println("❌❌❌ [LOCATION] Error CRÍTICO: ${e.message}")
                e.printStackTrace()
            } finally {
                println("🌐 [LOCATION] ==========================================")
            }
        }.start()
    }

    private fun updateNotification(text: String) {
        try {
            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("📍 Ubicación Activa")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setOngoing(true)
                .build()
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            println("⚠️ [LOCATION] Error actualizando notificación: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        println("💀 [LOCATION] ==========================================")
        println("💀 [LOCATION] LocationTrackingService onDestroy")
        println("💀 [LOCATION] ==========================================")
        
        try {
            fusedLocationClient.removeLocationUpdates(locationCallback)
            println("✅ [LOCATION] Actualizaciones de ubicación detenidas")
        } catch (e: Exception) {
            println("⚠️ [LOCATION] Error deteniendo actualizaciones: ${e.message}")
        }
        
        // ✅ LIBERAR WAKELOCK
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                println("✅ [LOCATION] WakeLock liberado")
            }
        } catch (e: Exception) {
            println("⚠️ [LOCATION] Error liberando WakeLock: ${e.message}")
        }
        
        // ✅ REINICIAR EL SERVICIO AUTOMÁTICAMENTE
        println("🔄 [LOCATION] Programando reinicio del servicio...")
        val restartIntent = Intent(applicationContext, LocationTrackingService::class.java)
        startService(restartIntent)
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        println("⚠️ [LOCATION] onTaskRemoved - Reiniciando servicio")
        
        val restartIntent = Intent(applicationContext, LocationTrackingService::class.java)
        startService(restartIntent)
    }
}