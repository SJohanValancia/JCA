import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  // Método principal simplificado
  Future<bool> requestPermissions(BuildContext context) async {
    try {
      // Verificar primero si ya están concedidos
      final locationStatus = await Permission.location.status;
      final cameraStatus = await Permission.camera.status;

      bool locationGranted = locationStatus.isGranted;
      bool cameraGranted = cameraStatus.isGranted;

      // Solo pedir ubicación si no está concedida
      if (!locationGranted) {
        if (context.mounted) {
          final shouldRequest = await _showPermissionDialog(context, Permission.location);
          if (shouldRequest) {
            final status = await Permission.location.request();
            locationGranted = status.isGranted;
            
            // Si deniega permanentemente, mostrar configuración
            if (status.isPermanentlyDenied) {
              await _showSettingsDialog(context, 'Ubicación');
            }
          }
        }
      }

      // Solo pedir cámara si no está concedida
      if (!cameraGranted && context.mounted) {
        final shouldRequest = await _showPermissionDialog(context, Permission.camera);
        if (shouldRequest) {
          final status = await Permission.camera.request();
          cameraGranted = status.isGranted;
          
          if (status.isPermanentlyDenied) {
            await _showSettingsDialog(context, 'Cámara');
          }
        }
      }

      return locationGranted && cameraGranted;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<bool> _showSettingsDialog(BuildContext context, String permissionName) async {
    if (!context.mounted) return false;
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permiso de $permissionName denegado'),
        content: Text(
          'Has denegado permanentemente el permiso de $permissionName. '
          'Por favor, ve a Configuración para habilitarlo manualmente.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context, true);
              await openAppSettings();
            },
            child: const Text('Ir a Configuración'),
          ),
        ],
      ),
    ) ?? false;
  }

  // Tu método _showPermissionDialog existente se queda igual
  Future<bool> _showPermissionDialog(
    BuildContext context,
    Permission permission,
  ) async {
    String title = '';
    String message = '';
    IconData icon = Icons.info;

    if (permission == Permission.location) {
      title = 'Permiso de Ubicación';
      message = 'JCA necesita acceso a tu ubicación para:\n\n'
          '• Mostrar tu posición actual en el mapa\n'
          '• Encontrar estaciones de policía cercanas\n'
          '• Enviar tu ubicación en caso de emergencia';
      icon = Icons.location_on;
    } else if (permission == Permission.camera) {
      title = 'Permiso de Cámara';
      message = 'JCA necesita acceso a tu cámara para:\n\n'
          '• Tomar fotos de evidencia en caso de emergencia\n'
          '• Grabar videos durante situaciones de riesgo';
      icon = Icons.camera_alt;
    }

    if (!context.mounted) return false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(icon, color: const Color(0xFF2563EB), size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
              ),
              child: const Text('Permitir'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<bool> checkLocationPermission() async {
    return await Permission.location.isGranted;
  }
}