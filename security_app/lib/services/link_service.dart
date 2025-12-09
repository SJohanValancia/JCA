import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/linked_user_model.dart';

class LinkService {
  static const String baseUrl = 'https://jca-labd.onrender.com';
  final storage = const FlutterSecureStorage();
  static const Duration _timeout = Duration(seconds: 15);

  // Obtener headers con token
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Enviar solicitud de vinculación
  Future<Map<String, dynamic>> sendLinkRequest(String jcId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/link/request'),
        headers: headers,
        body: jsonEncode({'jcId': jcId}),
      ).timeout(_timeout);

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
      print('Error enviando solicitud: $e');
      return {
        'success': false,
        'message': 'Error de conexión'
      };
    }
  }

  // Obtener solicitudes pendientes
  Future<List<LinkRequest>> getPendingRequests() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/link/pending'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List requests = data['requests'] ?? [];
        return requests.map((r) => LinkRequest.fromJson(r)).toList();
      }
      return [];
    } catch (e) {
      print('Error obteniendo solicitudes: $e');
      return [];
    }
  }

  // Responder a solicitud (aceptar/rechazar)
  Future<bool> respondToRequest(String linkId, bool accept) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/link/respond'),
        headers: headers,
        body: jsonEncode({
          'linkId': linkId,
          'accept': accept,
        }),
      ).timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error respondiendo solicitud: $e');
      return false;
    }
  }

  // Obtener dispositivos vinculados
  Future<List<LinkedUserModel>> getLinkedDevices() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/link/devices'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List devices = data['linkedDevices'] ?? [];
        return devices.map((d) => LinkedUserModel.fromJson(d['linkedUserId'])).toList();
      }
      return [];
    } catch (e) {
      print('Error obteniendo dispositivos: $e');
      return [];
    }
  }

  // Actualizar ubicación
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
      print('Error actualizando ubicación: $e');
      return false;
    }
  }

  // Obtener ubicaciones de dispositivos vinculados
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
      print('Error obteniendo ubicaciones: $e');
      return [];
    }
  }

  // Desvincular dispositivo
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
      print('Error desvinculando: $e');
      return false;
    }
  }
}