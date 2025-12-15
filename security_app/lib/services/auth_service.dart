import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
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
      
      // ✅ AGREGAR ESTOS PRINTS:
      print('═══════════════════════════════════════');
      print('📦 Response completo: $data');
      print('───────────────────────────────────────');
      print('💰 DeudaInfo en response: ${data['usuario']?['deudaInfo']}');
      print('💵 Deuda Total: ${data['usuario']?['deudaInfo']?['deudaTotal']}');
      print('💵 Deuda Restante: ${data['usuario']?['deudaInfo']?['deudaRestante']}');
      print('💳 Cuotas Pagadas: ${data['usuario']?['deudaInfo']?['cuotasPagadas']}');
      print('💳 Cuotas Pendientes: ${data['usuario']?['deudaInfo']?['cuotasPendientes']}');
      print('💰 Monto Cuota: ${data['usuario']?['deudaInfo']?['montoCuota']}');
      print('═══════════════════════════════════════');

      if (response.statusCode == 200 && data['success']) {
        await storage.write(key: 'token', value: data['token']);
        
        final user = UserModel.fromJson(data['usuario']);
        
        // ✅ AGREGAR ESTOS PRINTS TAMBIÉN:
print('───────────────────────────────────────');
print('👤 USUARIO CREADO EN FLUTTER:');
print('   Nombre: ${user.nombre}');
print('   Rol: ${user.rol}');
print('   Deuda Total: ${user.deudaInfo?.deudaTotal}');
print('   Deuda Restante: ${user.deudaInfo?.deudaRestante}');
print('   Cuotas Pagadas: ${user.deudaInfo?.cuotasPagadas}');
print('   Cuotas Pendientes: ${user.deudaInfo?.cuotasPendientes}');
print('   Monto Cuota: ${user.deudaInfo?.montoCuota}');
print('═══════════════════════════════════════');
        
        await storage.write(key: 'user', value: jsonEncode(user.toJson()));

        if (user.isVendedor) {
          print('🏪 Vendedor detectado');
          await _registrarDispositivo();
          
          try {
            const platform = MethodChannel('com.example.security_app/device_owner');
            await platform.invokeMethod('startMonitorService');
            print('✅ Servicio de monitoreo iniciado');
          } catch (e) {
            print('❌ Error iniciando servicio: $e');
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

  Future<void> _startMonitorService() async {
    try {
      const platform = MethodChannel('com.example.security_app/device_owner');
      await platform.invokeMethod('startMonitorService');
      print('✅ Servicio de monitoreo iniciado');
    } catch (e) {
      print('❌ Error iniciando servicio: $e');
    }
  }

  Future<Map<String, dynamic>> _checkLockStatus() async {
    try {
      final token = await storage.read(key: 'token');
      print('🔑 Token usado: ${token?.substring(0, 20)}...');
      
      print('🌐 Consultando estado de bloqueo al backend...');
      print('🔗 URL: $baseUrl/api/lock/check');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/lock/check'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      print('📡 Status Code: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      
      print('⚠️ Status code diferente de 200');
      return {'success': false, 'isLocked': false};
    } catch (e) {
      print('❌ Error verificando estado: $e');
      return {'success': false, 'isLocked': false};
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
    } catch (e) {
      print('Error registrando dispositivo: $e');
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