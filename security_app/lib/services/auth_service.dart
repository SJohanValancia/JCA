import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import 'lock_polling_service.dart'; // ✅ IMPORTAR

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
        // ✅ Guardar token, user Y userId
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
        body: jsonEncode({
          'usuario': usuario,
          'password': password,
        }),
      ).timeout(_timeout);

      final data = jsonDecode(response.body);

      print('===== RESPUESTA DEL SERVIDOR =====');
      print('Status Code: ${response.statusCode}');
      print('Success: ${data['success']}');
      if (data['usuario'] != null) {
        print('User ID: ${data['usuario']['_id']}');
        print('JC-ID: ${data['usuario']['jcId']}');
        print('Rol: ${data['usuario']['rol']}');
      }
      print('==================================');

      if (response.statusCode == 200 && data['success']) {
        // ✅ Guardar token, user Y userId
        await storage.write(key: 'token', value: data['token']);
        await storage.write(key: 'user', value: jsonEncode(data['usuario']));
        await storage.write(key: 'userId', value: data['usuario']['_id']);
        
        print('✅ Login exitoso - User ID: ${data['usuario']['_id']}');
        print('✅ Token guardado: ${data['token'].substring(0, 20)}...');
        
        // ✅ INICIAR POLLING SOLO SI ES VENDEDOR
        if (data['usuario']['rol'] == 'vendedor') {
          print('🔄 Usuario es vendedor, iniciando polling de bloqueo...');
          Future.delayed(const Duration(seconds: 2), () {
            final lockPolling = LockPollingService();
            lockPolling.startPolling();
          });
        } else {
          print('👤 Usuario es dueño, no se inicia polling');
        }
        
        return {
          'success': true,
          'message': data['message'],
          'user': UserModel.fromJson(data['usuario']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error en el login',
        };
      }
    } catch (e) {
      print('❌ Error en login: $e');
      return {
        'success': false,
        'message': 'Error de conexión: No se pudo conectar al servidor',
      };
    }
  }

  Future<bool> isLoggedIn() async {
    String? token = await storage.read(key: 'token');
    return token != null;
  }

  Future<void> logout() async {
    // ✅ Detener polling si está activo
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