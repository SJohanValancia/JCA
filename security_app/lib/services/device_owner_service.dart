// lib/services/device_owner_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

class DeviceOwnerService {
  static const String baseUrl = 'https://jca-labd.onrender.com';
  final storage = const FlutterSecureStorage();
  static const Duration _timeout = Duration(seconds: 15);
  
  // Channel para comunicación con código nativo
  static const platform = MethodChannel('com.example.security_app/device_owner');

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Bloquear dispositivo (llamada al backend)
  Future<Map<String, dynamic>> lockDevice({
    required String vendedorId,
    required String lockMessage,
  }) async {
    try {
      final headers = await _getHeaders();
      
      print('🔒 Bloqueando dispositivo: $vendedorId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/lock/lock'),
        headers: headers,
        body: jsonEncode({
          'vendedorId': vendedorId,
          'lockMessage': lockMessage,
        }),
      ).timeout(_timeout);

      print('📡 Status: ${response.statusCode}');
      print('📦 Response: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al bloquear dispositivo'
        };
      }
    } catch (e) {
      print('❌ Error bloqueando dispositivo: $e');
      return {
        'success': false,
        'message': 'Error de conexión'
      };
    }
  }

  // Desbloquear dispositivo (llamada al backend)
  Future<Map<String, dynamic>> unlockDevice({
    required String vendedorId,
  }) async {
    try {
      final headers = await _getHeaders();
      
      print('🔓 Desbloqueando dispositivo: $vendedorId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/lock/unlock'),
        headers: headers,
        body: jsonEncode({
          'vendedorId': vendedorId,
        }),
      ).timeout(_timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al desbloquear dispositivo'
        };
      }
    } catch (e) {
      print('❌ Error desbloqueando dispositivo: $e');
      return {
        'success': false,
        'message': 'Error de conexión'
      };
    }
  }

  // Verificar estado de bloqueo (para vendedor)
// Verificar estado de bloqueo (para vendedor)
Future<Map<String, dynamic>> checkLockStatus() async {
  try {
    final headers = await _getHeaders();
    final token = await storage.read(key: 'token');
    
    // 🔍 DEBUG: Ver qué token se está usando
    print('🔑 Token usado: ${token?.substring(0, 20)}...');
    
    print('🌐 Consultando estado de bloqueo al backend...');
    print('🔗 URL: $baseUrl/api/lock/check');
    
    final response = await http.get(
      Uri.parse('$baseUrl/api/lock/check'),
      headers: headers,
    ).timeout(_timeout);

    print('📡 Status Code: ${response.statusCode}');
    print('📦 Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Datos parseados: $data');
      return data;
    }
    
    print('⚠️ Status code diferente de 200');
    return {'success': false, 'isLocked': false};
  } catch (e) {
    print('❌ Error verificando estado: $e');
    return {'success': false, 'isLocked': false};
  }
}
  // Obtener estado de bloqueo de un vendedor (para dueño)
  Future<Map<String, dynamic>> getLockStatus(String vendedorId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/lock/status/$vendedorId'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }
      
      return {'success': false, 'isLocked': false};
    } catch (e) {
      print('❌ Error obteniendo estado: $e');
      return {'success': false, 'isLocked': false};
    }
  }

  // Activar bloqueo nativo (Device Owner)
  Future<bool> activateNativeLock(String message) async {
    try {
      final result = await platform.invokeMethod('lockDevice', {
        'message': message,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('❌ Error activando bloqueo nativo: ${e.message}');
      return false;
    }
  }

  // Desactivar bloqueo nativo
  Future<bool> deactivateNativeLock() async {
    try {
      final result = await platform.invokeMethod('unlockDevice');
      return result == true;
    } on PlatformException catch (e) {
      print('❌ Error desactivando bloqueo nativo: ${e.message}');
      return false;
    }
  }

  // Verificar si el dispositivo está bloqueado localmente
  Future<bool> isDeviceLocked() async {
    try {
      final result = await platform.invokeMethod('isLocked');
      return result == true;
    } on PlatformException catch (e) {
      print('❌ Error verificando bloqueo: ${e.message}');
      return false;
    }
  }

// Forzar desbloqueo de emergencia
Future<bool> forceUnlock() async {
  try {
    print('🚨 Ejecutando desbloqueo de emergencia');
    final result = await platform.invokeMethod('forceUnlock');
    return result == true;
  } on PlatformException catch (e) {
    print('❌ Error en forceUnlock: ${e.message}');
    return false;
  }
}

}