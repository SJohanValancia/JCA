import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class AuthService {
  static const String baseUrl = 'https://jca-labd.onrender.com';
  final storage = const FlutterSecureStorage();

  // Registro
  Future<Map<String, dynamic>> register({
    required String nombre,
    required String telefono,
    required String usuario,
    required String password,
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
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success']) {
        await storage.write(key: 'token', value: data['token']);
        await storage.write(key: 'user', value: jsonEncode(data['usuario']));
        
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
        'message': 'Error de conexión: $e',
      };
    }
  }

  // Login
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
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await storage.write(key: 'token', value: data['token']);
        await storage.write(key: 'user', value: jsonEncode(data['usuario']));
        
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
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  // Verificar si hay sesión activa
  Future<bool> isLoggedIn() async {
    String? token = await storage.read(key: 'token');
    return token != null;
  }

  // Cerrar sesión
  Future<void> logout() async {
    await storage.delete(key: 'token');
    await storage.delete(key: 'user');
  }

  // Obtener usuario guardado
  Future<UserModel?> getUser() async {
    String? userJson = await storage.read(key: 'user');
    if (userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson));
    }
    return null;
  }
}