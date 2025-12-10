import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class AuthService {
  static const String baseUrl = 'https://jca-labd.onrender.com';
  final storage = const FlutterSecureStorage();
  
  static const Duration _timeout = Duration(seconds: 10);

Future<Map<String, dynamic>> register({
  required String nombre,
  required String telefono,
  required String usuario,
  required String password,
  String rol = 'dueno', // ✅ NUEVO parámetro
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
        'rol': rol, // ✅ AÑADIR ESTO
      }),
    ).timeout(_timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success']) {
        await Future.wait([
          storage.write(key: 'token', value: data['token']),
          storage.write(key: 'user', value: jsonEncode(data['usuario'])),
        ]);
        
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
      return {
        'success': false,
        'message': 'Error de conexion: No se pudo conectar al servidor',
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

      // ✅ LOGS PARA DEBUG
      print('===== RESPUESTA DEL SERVIDOR =====');
      print('Status Code: ${response.statusCode}');
      print('Data completa: $data');
      if (data['usuario'] != null) {
        print('Usuario: ${data['usuario']}');
        print('JC-ID recibido: ${data['usuario']['jcId']}');
      }
      print('==================================');

      if (response.statusCode == 200 && data['success']) {
        await Future.wait([
          storage.write(key: 'token', value: data['token']),
          storage.write(key: 'user', value: jsonEncode(data['usuario'])),
        ]);
        
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
      print('ERROR en login: $e');
      return {
        'success': false,
        'message': 'Error de conexion: No se pudo conectar al servidor',
      };
    }
  }

  Future<bool> isLoggedIn() async {
    String? token = await storage.read(key: 'token');
    return token != null;
  }

  Future<void> logout() async {
    await Future.wait([
      storage.delete(key: 'token'),
      storage.delete(key: 'user'),
    ]);
  }

  Future<UserModel?> getUser() async {
    String? userJson = await storage.read(key: 'user');
    if (userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson));
    }
    return null;
  }
}