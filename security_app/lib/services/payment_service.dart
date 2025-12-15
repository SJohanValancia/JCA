import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PaymentService {
  static const String baseUrl = 'https://jca-labd.onrender.com';
  final storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> registrarAbono({
    required String vendedorId,
    required double montoAbono,
  }) async {
    try {
      final token = await storage.read(key: 'token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/payment/registrar-abono'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'vendedorId': vendedorId,
          'montoAbono': montoAbono,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'message': data['message'],
          'deudaActualizada': data['deudaActualizada'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al registrar abono',
        };
      }
    } catch (e) {
      print('❌ Error en registrarAbono: $e');
      return {
        'success': false,
        'message': 'Error de conexión',
      };
    }
  }
}