import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import 'lock_polling_service.dart'; // ✅ IMPORTAR
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

// Modificar el método login en auth_service.dart:
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

    if (response.statusCode == 200 && data['success']) {
      await storage.write(key: 'token', value: data['token']);
      
      final user = UserModel.fromJson(data['usuario']);
      await storage.write(key: 'user', value: jsonEncode(user.toJson()));

      // ✅ SI ES VENDEDOR, REGISTRAR DISPOSITIVO
      if (user.isVendedor) {
        await _registrarDispositivo();
      }

      return {'success': true, 'message': data['message'], 'user': user};
    }
    
    return {'success': false, 'message': data['message']};
  } catch (e) {
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
  } catch (e) {
    print('Error registrando dispositivo: $e');
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