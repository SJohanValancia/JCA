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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
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
    private val handler = Handler(Looper.getMainLooper())
    
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()
    
    private val baseUrl = "https://jca-labd.onrender.com"

    companion object {
        private const val CHANNEL_ID = "location_tracking_channel"
        private const val NOTIFICATION_ID = 3
    }

    override fun onCreate() {
        super.onCreate()
        println("📍 [LOCATION] LocationTrackingService onCreate")
        
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        setupLocationCallback()
        startLocationUpdates()
        
        println("✅ [LOCATION] Servicio de ubicación iniciado")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Seguimiento de Ubicación",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Envía tu ubicación en tiempo real"
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
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun setupLocationCallback() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    println("📍 [LOCATION] Nueva ubicación: ${location.latitude}, ${location.longitude}")
                    sendLocationToBackend(location)
                }
            }
        }
    }

    private fun startLocationUpdates() {
        val locationRequest = LocationRequest.create().apply {
            interval = 10000 // ✅ Cada 10 segundos
            fastestInterval = 5000
            priority = LocationRequest.PRIORITY_HIGH_ACCURACY
        }

        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
            println("✅ [LOCATION] Actualizaciones de ubicación iniciadas")
        } else {
            println("❌ [LOCATION] Sin permisos de ubicación")
        }
    }

private fun sendLocationToBackend(location: Location) {
    Thread {
        try {
            println("🌐 [LOCATION] ==========================================")
            println("📍 [LOCATION] Enviando ubicación al backend...")
            
            val securePrefs = getSharedPreferences(
                "flutter.flutter_secure_storage",
                Context.MODE_PRIVATE
            )
            val token = securePrefs.getString("flutter.token", null)

            if (token == null) {
                println("⚠️ [LOCATION] No hay token - ABORTANDO")
                return@Thread
            }

            println("✅ [LOCATION] Token encontrado: ${token.substring(0, 20)}...")
            println("📍 [LOCATION] Lat: ${location.latitude}, Lon: ${location.longitude}")
            println("🎯 [LOCATION] Accuracy: ${location.accuracy} metros")

            val json = JSONObject().apply {
                put("latitude", location.latitude)
                put("longitude", location.longitude)
                put("accuracy", location.accuracy)
            }

            println("📦 [LOCATION] JSON: ${json.toString()}")

            val body = json.toString().toRequestBody("application/json".toMediaType())

            // ✅ URL CORREGIDA
            val url = "$baseUrl/api/link/location/update"
            println("🔗 [LOCATION] URL: $url")

            val request = Request.Builder()
                .url(url)  // ✅ ESTA ES LA CORRECCIÓN PRINCIPAL
                .addHeader("Authorization", "Bearer $token")
                .post(body)
                .build()

            println("📡 [LOCATION] Enviando request...")
            val response = client.newCall(request).execute()

            println("📊 [LOCATION] Status Code: ${response.code}")
            
            if (response.isSuccessful) {
                println("✅✅✅ [LOCATION] Ubicación enviada EXITOSAMENTE")
            } else {
                val errorBody = response.body?.string() ?: "Sin respuesta"
                println("❌ [LOCATION] Error ${response.code}: $errorBody")
            }

        } catch (e: Exception) {
            println("❌❌❌ [LOCATION] Error CRÍTICO: ${e.message}")
            e.printStackTrace()
        } finally {
            println("🌐 [LOCATION] ==========================================")
        }
    }.start()
}

    override fun onDestroy() {
        super.onDestroy()
        println("💀 [LOCATION] LocationTrackingService onDestroy")
        
        try {
            fusedLocationClient.removeLocationUpdates(locationCallback)
        } catch (e: Exception) {
            println("⚠️ [LOCATION] Error deteniendo actualizaciones: ${e.message}")
        }
    }
}