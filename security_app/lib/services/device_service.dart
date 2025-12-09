import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceService {
  static const String baseUrl = 'https://jca-labd.onrender.com';
  final storage = const FlutterSecureStorage();
  static const Duration _timeout = Duration(seconds: 10);

  Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'deviceName': '${androidInfo.brand} ${androidInfo.model}',
        'deviceModel': androidInfo.model,
        'deviceId': androidInfo.id,
        'platform': 'Android',
        'version': androidInfo.version.release,
      };
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return {
        'deviceName': '${iosInfo.name} ${iosInfo.model}',
        'deviceModel': iosInfo.model,
        'deviceId': iosInfo.identifierForVendor ?? 'unknown',
        'platform': 'iOS',
        'version': iosInfo.systemVersion,
      };
    }
    
    return {
      'deviceName': 'Unknown Device',
      'deviceModel': 'Unknown',
      'deviceId': 'unknown',
      'platform': 'Unknown',
      'version': 'Unknown',
    };
  }

  Future<bool> saveDeviceToBackend() async {
    try {
      final deviceInfo = await getDeviceInfo();
      final token = await storage.read(key: 'token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/devices/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(deviceInfo),
      ).timeout(_timeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error saving device: $e');
      return false;
    }
  }
}