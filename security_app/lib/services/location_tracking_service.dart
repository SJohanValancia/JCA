import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'link_service.dart';
import 'battery_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  final _linkService = LinkService();
  final _batteryService = BatteryService();
  Timer? _locationTimer;
  bool _isTracking = false;

  // ✅ Iniciar seguimiento de ubicación cada 10 segundos
  Future<void> startTracking() async {
    if (_isTracking) {
      print('⚠️ Ya está rastreando ubicación');
      return;
    }

    print('📍 Iniciando seguimiento de ubicación en tiempo real');
    _isTracking = true;

    // Primera actualización inmediata
    await _updateLocation();

    // Actualizaciones periódicas cada 10 segundos
    _locationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) async {
        await _updateLocation();
      },
    );
  }

  // ✅ Detener seguimiento
  void stopTracking() {
    print('🛑 Deteniendo seguimiento de ubicación');
    _locationTimer?.cancel();
    _locationTimer = null;
    _isTracking = false;
  }

  // ✅ Actualizar ubicación
  Future<void> _updateLocation() async {
    try {
      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('⚠️ Permiso de ubicación denegado');
        return;
      }

      // Obtener ubicación actual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Obtener dirección
      String? address = await _getAddressFromCoordinates(position);

      // Obtener batería
      int batteryLevel = await _batteryService.getBatteryLevel();
      bool isCharging = await _batteryService.isCharging();

      // Enviar al backend
      await _linkService.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        batteryLevel: batteryLevel,
        isCharging: isCharging,
        accuracy: position.accuracy,
      );

      print('✅ Ubicación actualizada: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('❌ Error actualizando ubicación: $e');
    }
  }

  // ✅ Obtener dirección desde coordenadas
  Future<String?> _getAddressFromCoordinates(Position position) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=${position.latitude}&lon=${position.longitude}&format=json&addressdetails=1'
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'JCA-App'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        
        List<String> parts = [];
        
        if (address['road'] != null) {
          parts.add(address['road']);
        }
        if (address['house_number'] != null) {
          parts.add('#${address['house_number']}');
        }
        if (address['suburb'] != null || address['neighbourhood'] != null) {
          parts.add(address['suburb'] ?? address['neighbourhood']);
        }
        if (address['city'] != null || address['town'] != null) {
          parts.add(address['city'] ?? address['town']);
        }

        return parts.isNotEmpty ? parts.join(', ') : data['display_name'];
      }
    } catch (e) {
      print('Error obteniendo dirección: $e');
    }
    return null;
  }

  bool get isTracking => _isTracking;
}