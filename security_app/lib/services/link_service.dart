import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/linked_user_model.dart';
import '../models/debt_config_model.dart';
import '../models/user_model.dart'; 

class LinkService {
  static const String baseUrl = 'https://jca-labd.onrender.com';
  final storage = const FlutterSecureStorage();
  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> sendLinkRequest(String jcId) async {
    try {
      final headers = await _getHeaders();
      
      print('📤 Enviando solicitud a: $jcId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/link/request'),
        headers: headers,
        body: jsonEncode({'jcId': jcId}),
      ).timeout(_timeout);

      print('📡 Status: ${response.statusCode}');
      print('📦 Response: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'targetUser': data['targetUser']
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al enviar solicitud'
        };
      }
    } catch (e) {
      print('❌ Error enviando solicitud: $e');
      return {
        'success': false,
        'message': 'Error de conexión'
      };
    }
  }

  Future<List<LinkRequest>> getPendingRequests() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/link/pending'),
        headers: headers,
      ).timeout(_timeout);

      print('📋 Pending requests status: ${response.statusCode}');
      print('📋 Pending requests body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List requests = data['requests'] ?? [];
        
        print('✅ Solicitudes pendientes: ${requests.length}');
        
        return requests.map((r) => LinkRequest.fromJson(r)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Error obteniendo solicitudes: $e');
      return [];
    }
  }

  // ✅ ARREGLADO: Responder a solicitud
  Future<bool> respondToRequest(String linkId, bool accept) async {
    try {
      final headers = await _getHeaders();
      
      print('🔄 Respondiendo solicitud: $linkId - accept: $accept');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/link/respond'),
        headers: headers,
        body: jsonEncode({
          'linkId': linkId,
          'accept': accept,
        }),
      ).timeout(_timeout);

      print('📡 Status: ${response.statusCode}');
      print('📦 Response: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error respondiendo solicitud: $e');
      return false;
    }
  }

  // ✅ ARREGLADO: Obtener dispositivos vinculados
Future<List<LinkedUserModel>> getLinkedDevices() async {
  try {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/api/link/devices'),
      headers: headers,
    ).timeout(_timeout);

    print('📱 Linked devices status: ${response.statusCode}');
    print('📱 Linked devices body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List devices = data['linkedDevices'] ?? [];
      
      print('✅ Dispositivos vinculados: ${devices.length}');
      
      // ✅ CORREGIDO: Leer directamente del objeto, no de linkedUserId
      return devices.map((d) {
        // ✅ Ya no buscar linkedUserId, usar directamente 'd'
        if (d == null) {
          print('⚠️ Dispositivo es null');
          return null;
        }
        
        return LinkedUserModel(
          id: d['id'] ?? '',  // ✅ Cambio aquí
          nombre: d['nombre'] ?? '',
          usuario: d['usuario'] ?? '',
          jcId: d['jcId'] ?? '',
          rol: d['rol'],
          deudaInfo: d['deudaInfo'] != null
              ? DeudaInfo.fromJson(d['deudaInfo'])
              : null,
        );
      })
      .where((device) => device != null)
      .cast<LinkedUserModel>()
      .toList();
    }
    return [];
  } catch (e) {
    print('❌ Error obteniendo dispositivos: $e');
    return [];
  }
}
 Future<bool> updateLocation({
    required double latitude,
    required double longitude,
    String? address,
    int? batteryLevel,
    bool? isCharging,
    double? accuracy,
  }) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/link/location/update'),
        headers: headers,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'batteryLevel': batteryLevel,
          'isCharging': isCharging,
          'accuracy': accuracy,
        }),
      ).timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error actualizando ubicación: $e');
      return false;
    }
  }

  Future<List<LinkedUserModel>> getLinkedLocations() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/link/location/linked'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List locations = data['locations'] ?? [];
        return locations.map((l) => LinkedUserModel.fromJson(l)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Error obteniendo ubicaciones: $e');
      return [];
    }
  }

  Future<bool> unlinkDevice(String linkedUserId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/link/unlink'),
        headers: headers,
        body: jsonEncode({'linkedUserId': linkedUserId}),
      ).timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error desvinculando: $e');
      return false;
    }
  }

 Future<Map<String, dynamic>> configureDebt({
    required String linkedUserId,
    required DebtConfig debtConfig,
  }) async {
    try {
      final headers = await _getHeaders();
      
      print('📊 Configurando deuda para: $linkedUserId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/link/debt/configure'),
        headers: headers,
        body: jsonEncode({
          'linkedUserId': linkedUserId,
          'debtConfig': debtConfig.toJson(),
        }),
      ).timeout(_timeout);

      print('📡 Status: ${response.statusCode}');
      print('📦 Response: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'debtConfig': data['debtConfig']
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error configurando deuda'
        };
      }
    } catch (e) {
      print('❌ Error configurando deuda: $e');
      return {
        'success': false,
        'message': 'Error de conexión'
      };
    }
  }

  // ✅ NUEVO: Obtener configuración de deuda
  Future<DebtConfig?> getDebtConfig(String linkedUserId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/link/debt/$linkedUserId'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['debtConfig'] != null && (data['debtConfig'] as Map).isNotEmpty) {
          return DebtConfig.fromJson(data['debtConfig']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo configuración: $e');
      return null;
    }
  }

  // ✅ NUEVO: Registrar pago
  Future<bool> registerPayment({
    required String linkedUserId,
    required double montoPagado,
  }) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/link/debt/payment'),
        headers: headers,
        body: jsonEncode({
          'linkedUserId': linkedUserId,
          'montoPagado': montoPagado,
        }),
      ).timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error registrando pago: $e');
      return false;
    }
  }


  // ✅ NUEVO: Obtener solo ubicaciones de vendedores bloqueados
Future<List<LinkedUserModel>> getBlockedVendorsLocations() async {
  try {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$baseUrl/api/link/location/blocked-vendors'),
      headers: headers,
    ).timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List locations = data['locations'] ?? [];
      
      print('📍 Vendedores bloqueados recibidos: ${locations.length}');
      
      return locations.map((l) => LinkedUserModel.fromJson(l)).toList();
    }
    return [];
  } catch (e) {
    print('❌ Error obteniendo vendedores bloqueados: $e');
    return [];
  }
}

}

