import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact_model.dart';

class ContactService {
  // ✅ URL de producción de Render
  static const String _baseUrl = 'https://jca-labd.onrender.com/api/contacts';

  // Solicitar permiso de contactos
  Future<bool> requestContactsPermission() async {
    try {
      return await FlutterContacts.requestPermission();
    } catch (e) {
      print('❌ Error solicitando permiso: $e');
      return false;
    }
  }

  // Obtener contactos del dispositivo
  Future<List<Contact>> getDeviceContacts() async {
    try {
      final hasPermission = await FlutterContacts.requestPermission();
      if (!hasPermission) return [];

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      print('📱 Contactos del dispositivo: ${contacts.length}');
      return contacts;
    } catch (e) {
      print('❌ Error obteniendo contactos: $e');
      return [];
    }
  }

  // Obtener contactos de emergencia desde el backend
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('❌ No hay token');
        return [];
      }

      print('🔍 Obteniendo contactos de emergencia...');
      final response = await http.get(
        Uri.parse('$_baseUrl/emergency'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Status: ${response.statusCode}');
      print('📦 Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> contacts = data['emergencyContacts'] ?? [];
        
        print('✅ Contactos de emergencia: ${contacts.length}');
        return contacts.map((json) => EmergencyContact.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('❌ Error obteniendo contactos de emergencia: $e');
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('❌ No hay token');
        return false;
      }

      print('🔄 Toggle contacto: $name - $phoneNumber - isEmergency: $isEmergency');

      final response = await http.post(
        Uri.parse('$_baseUrl/emergency'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'phoneNumber': phoneNumber,
          'isEmergency': isEmergency,
        }),
      );

      print('📡 Status: ${response.statusCode}');
      print('📦 Response: ${response.body}');

      return response.statusCode == 201 || response.statusCode == 200;

    } catch (e) {
      print('❌ Error toggling contacto: $e');
      return false;
    }
  }
}