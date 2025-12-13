import 'package:flutter/services.dart';

class AppProtectionService {
  static const platform = MethodChannel('com.example.security_app/device_owner');
  
  // Liberar app de un vendedor específico
  Future<bool> releaseApp(String vendorId) async {
    try {
      final result = await platform.invokeMethod('releaseApp', {
        'vendorId': vendorId,
      });
      return result == true;
    } catch (e) {
      print('❌ Error liberando app: $e');
      return false;
    }
  }
  
  // Verificar si la app está protegida
  Future<bool> isAppProtected() async {
    try {
      final result = await platform.invokeMethod('isAppProtected');
      return result == true;
    } catch (e) {
      print('❌ Error verificando protección: $e');
      return true; // Por defecto, protegida
    }
  }
  
  // Activar lockdown extremo
  Future<bool> lockDownDevice() async {
    try {
      final result = await platform.invokeMethod('lockDownDevice');
      return result == true;
    } catch (e) {
      print('❌ Error en lockdown: $e');
      return false;
    }
  }
}