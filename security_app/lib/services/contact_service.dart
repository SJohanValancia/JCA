import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emergency_contact_model.dart';

class ContactService {
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

  // Solicitar permiso de contactos
  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  // Obtener todos los contactos del dispositivo
  Future<List<Contact>> getDeviceContacts() async {
    final hasPermission = await requestContactsPermission();
    if (!hasPermission) return [];

    try {
      final contacts = await ContactsService.getContacts();
      return contacts.toList();
    } catch (e) {
      print('Error obteniendo contactos: $e');
      return [];
    }
  }

  // Marcar/desmarcar contacto como emergencia
  Future<bool> toggleEmergencyContact({
    required String name,
    required String phoneNumber,
    required bool isEmergency,
  }) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/contacts/emergency'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'phoneNumber': phoneNumber,
          'isEmergency': isEmergency,
        }),
      ).timeout(_timeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error actualizando contacto de emergencia: $e');
      return false;
    }
  }

  // Obtener contactos de emergencia guardados
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/contacts/emergency'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List contacts = data['emergencyContacts'] ?? [];
        return contacts.map((c) => EmergencyContact.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      print('Error obteniendo contactos de emergencia: $e');
      return [];
    }
  }

  // Eliminar contacto de emergencia
  Future<bool> removeEmergencyContact(String contactId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.delete(
        Uri.parse('$baseUrl/api/contacts/emergency/$contactId'),
        headers: headers,
      ).timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error eliminando contacto de emergencia: $e');
      return false;
    }
  }
}