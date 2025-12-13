// lib/services/lock_polling_service.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'device_owner_service.dart';

class LockPollingService {
  static final LockPollingService _instance = LockPollingService._internal();
  factory LockPollingService() => _instance;
  LockPollingService._internal();

  final _deviceOwnerService = DeviceOwnerService();
  Timer? _pollTimer;
  bool _isPolling = false;
  static const platform = MethodChannel('com.example.security_app/device_owner');

  void startPolling() {
    if (_isPolling) return;
    
    print('🔄 Iniciando polling de bloqueo...');
    _isPolling = true;
    
    Future.delayed(const Duration(seconds: 2), () {
      _checkLockStatus();
      
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
        await _checkLockStatus();
      });
    });
  }

  void stopPolling() {
    print('ℹ️ Deteniendo polling de bloqueo');
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
  }

  Future<void> _checkLockStatus() async {
    try {
      print('🔍 Verificando estado de bloqueo en backend...');
      
      final status = await _deviceOwnerService.checkLockStatus();
      
      print('📊 Estado recibido del backend: $status');
      
      if (status['isLocked'] == true) {
        final message = status['lockMessage'] ?? 'Dispositivo bloqueado';
        print('🔒 BLOQUEO DETECTADO - Mensaje: $message');
        
        await _activateNativeLock(message);
      } else {
        print('✅ Dispositivo NO bloqueado según backend');
        
        await _deactivateNativeLock();
      }
    } catch (e) {
      print('❌ Error en polling: $e');
    }
  }

  Future<void> _activateNativeLock(String message) async {
    try {
      final isCurrentlyLocked = await platform.invokeMethod('isLocked');
      
      if (isCurrentlyLocked != true) {
        print('🔐 Activando bloqueo nativo...');
        final result = await platform.invokeMethod('lockDevice', {
          'message': message,
        });
        
        if (result == true) {
          print('✅ Bloqueo nativo activado exitosamente');
          // ✅ YA NO CERRAMOS FLUTTER - Dejamos que el servicio nativo maneje todo
        } else {
          print('⚠️ No se pudo activar el bloqueo nativo');
        }
      } else {
        print('ℹ️ El dispositivo ya está bloqueado');
      }
    } catch (e) {
      print('❌ Error activando bloqueo nativo: $e');
    }
  }

  Future<void> _deactivateNativeLock() async {
    try {
      final isCurrentlyLocked = await platform.invokeMethod('isLocked');
      
      if (isCurrentlyLocked == true) {
        print('🔓 Desactivando bloqueo nativo...');
        final result = await platform.invokeMethod('unlockDevice');
        
        if (result == true) {
          print('✅ Bloqueo nativo desactivado exitosamente');
        }
      }
    } on PlatformException catch (e) {
      print('⚠️ Plugin no disponible aún: ${e.message}');
    } catch (e) {
      print('❌ Error desactivando bloqueo nativo: $e');
    }
  }

  Future<void> forceCheck() async {
    print('⚡ Verificación forzada');
    await _checkLockStatus();
  }
}