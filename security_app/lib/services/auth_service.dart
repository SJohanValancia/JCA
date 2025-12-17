import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_model.dart';
import 'lock_polling_service.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AuthService {
  static const String baseUrl = 'https://jca-labd.onrender.com';
  final storage = const FlutterSecureStorage();
  
  static const Duration _timeout = Duration(seconds: 10);

  Future<Map<String, dynamic>> register({
    required String nombre,
    required String telefono,
    required String usuario,
    required String password,
    String rol = 'dueno',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'telefono': telefono,
          'usuario': usuario,
          'password': password,
          'rol': rol,
        }),
      ).timeout(_timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success']) {
        await storage.write(key: 'token', value: data['token']);
        await storage.write(key: 'user', value: jsonEncode(data['usuario']));
        await storage.write(key: 'userId', value: data['usuario']['_id']);
        
        print('✅ Registro exitoso - User ID: ${data['usuario']['_id']}');
        
        return {
          'success': true,
          'message': data['message'],
          'user': UserModel.fromJson(data['usuario']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error en el registro',
        };
      }
    } catch (e) {
      print('❌ Error en registro: $e');
      return {
        'success': false,
        'message': 'Error de conexión: No se pudo conectar al servidor',
      };
    }
  }

  Future<Map<String, dynamic>> login({
    required String usuario,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'usuario': usuario, 'password': password}),
      ).timeout(_timeout);

      final data = jsonDecode(response.body);
      
      print('═══════════════════════════════════════════');
      print('📦 Response completo: $data');
      print('───────────────────────────────────────────');
      print('💰 DeudaInfo en response: ${data['usuario']?['deudaInfo']}');
      print('═══════════════════════════════════════════');

      if (response.statusCode == 200 && data['success']) {
        await storage.write(key: 'token', value: data['token']);
        
        final user = UserModel.fromJson(data['usuario']);
        
        print('───────────────────────────────────────────');
        print('👤 USUARIO CREADO EN FLUTTER:');
        print('   Nombre: ${user.nombre}');
        print('   Rol: ${user.rol}');
        print('   Deuda Total: ${user.deudaInfo?.deudaTotal}');
        print('═══════════════════════════════════════════');
        
        await storage.write(key: 'user', value: jsonEncode(user.toJson()));

        if (user.isVendedor) {
          print('🛒 Vendedor detectado');
          
          // ✅ 1. SOLICITAR PERMISOS DE UBICACIÓN
          try {
            print('📍 Verificando permisos de ubicación...');
            
            var status = await Permission.location.status;
            if (!status.isGranted) {
              print('📍 Solicitando permiso de ubicación...');
              final result = await Permission.location.request();
              if (result.isGranted) {
                print('✅ Permiso de ubicación concedido');
              } else {
                print('⚠️ Permiso de ubicación denegado');
              }
            } else {
              print('✅ Permiso de ubicación ya concedido');
            }
            
            var bgStatus = await Permission.locationAlways.status;
            if (!bgStatus.isGranted) {
              print('📍 Solicitando permiso de ubicación en segundo plano...');
              final bgResult = await Permission.locationAlways.request();
              if (bgResult.isGranted) {
                print('✅ Permiso de ubicación en segundo plano concedido');
              } else {
                print('⚠️ Permiso de ubicación en segundo plano denegado');
              }
            } else {
              print('✅ Permiso de ubicación en segundo plano ya concedido');
            }
            
            // ✅ SOLICITAR PERMISOS DE NOTIFICACIONES
            var notifStatus = await Permission.notification.status;
            if (!notifStatus.isGranted) {
              print('🔔 Solicitando permiso de notificaciones...');
              final notifResult = await Permission.notification.request();
              if (notifResult.isGranted) {
                print('✅ Permiso de notificaciones concedido');
              } else {
                print('⚠️ Permiso de notificaciones denegado');
              }
            } else {
              print('✅ Permiso de notificaciones ya concedido');
            }
            
            print('✅ Permisos verificados completamente');
          } catch (e) {
            print('⚠️ Error solicitando permisos: $e');
          }
          
          // ✅ 2. REGISTRAR DISPOSITIVO
          await _registrarDispositivo();
          
          // ✅ 3. INICIAR SERVICIO DE UBICACIÓN
          try {
            const platform = MethodChannel('com.example.security_app/device_owner');
            await platform.invokeMethod('startLocationService');
            print('✅ Servicio de ubicación iniciado desde login');
          } catch (e) {
            print('⚠️ Error iniciando servicio de ubicación: $e');
          }
          
          // ✅ 4. INICIAR MONITOR DE UBICACIÓN
          try {
            const platform = MethodChannel('com.example.security_app/device_owner');
            await platform.invokeMethod('startLocationMonitor');
            print('✅ Monitor de ubicación iniciado desde login');
          } catch (e) {
            print('⚠️ Error iniciando monitor de ubicación: $e');
          }
          
          // ✅ 5. INICIAR SERVICIO DE MONITOREO
          try {
            const platform = MethodChannel('com.example.security_app/device_owner');
            await platform.invokeMethod('startMonitorService');
            print('✅ Servicio de monitoreo iniciado desde login');
          } catch (e) {
            print('❌ Error iniciando servicio de monitoreo: $e');
          }
          
          // ✅ 6. INICIAR MONITOR DE PAGOS
          try {
            const platform = MethodChannel('com.example.security_app/device_owner');
            await platform.invokeMethod('startPaymentMonitor');
            print('✅ Monitor de pagos iniciado desde login');
          } catch (e) {
            print('⚠️ Error iniciando monitor de pagos: $e');
          }
        }

        return {'success': true, 'message': data['message'], 'user': user};
      }
      
      return {'success': false, 'message': data['message']};
    } catch (e) {
      print('❌ Error en login: $e');
      return {'success': false, 'message': 'Error de conexión'};
    }
  }

  Future<void> _registrarDispositivo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      final token = await storage.read(key: 'token');
      
      await http.post(
        Uri.parse('$baseUrl/api/auth/registrar-dispositivo'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'deviceId': androidInfo.id,
          'deviceInfo': {
            'modelo': androidInfo.model,
            'marca': androidInfo.brand,
            'version': androidInfo.version.release,
          }
        }),
      );
      
      print('✅ Dispositivo registrado exitosamente');
    } catch (e) {
      print('❌ Error registrando dispositivo: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    String? token = await storage.read(key: 'token');
    return token != null;
  }

  Future<void> logout() async {
    final lockPolling = LockPollingService();
    lockPolling.stopPolling();
    
    await storage.deleteAll();
    print('✅ Sesión cerrada completamente');
  }

  Future<UserModel?> getUser() async {
    String? userJson = await storage.read(key: 'user');
    if (userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson));
    }
    return null;
  }
}