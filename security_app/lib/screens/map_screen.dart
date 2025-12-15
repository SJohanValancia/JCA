import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../models/linked_user_model.dart';
import '../services/link_service.dart';
import '../services/battery_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController? _mapController;
  Position? _currentPosition;
  final List<Marker> _userMarkers = [];
  final List<Marker> _emergencyMarkers = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDisposed = false;
  String? _currentAddress;
  bool _isMapReady = false; // ✅ NUEVO
  
  final _linkService = LinkService();
  final _batteryService = BatteryService();
  List<LinkedUserModel> _linkedLocations = [];
  Timer? _locationUpdateTimer;
  
  String _currentStyle = 'OpenStreetMap';
  
  final Map<String, String> _mapStyles = {
    'OpenStreetMap': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'CartoDB Voyager': 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    'Stadia Smooth': 'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png',
  };

  final Map<String, bool> _placeTypes = {
    'police': true,
    'hospital': true,
    'clinic': true,
    'fire_station': true,
    'townhall': true,
    'pharmacy': true,
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // ✅ Cambiar estado inicial para que el mapa se renderice
    _isLoading = false;
  }

  void _startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        if (_currentPosition != null) {
          await _updateMyLocation();
          await _loadLinkedLocations();
        }
      },
    );
  }

  Future<void> _updateMyLocation() async {
    if (_currentPosition == null) return;

    final batteryLevel = await _batteryService.getBatteryLevel();
    final isCharging = await _batteryService.isCharging();

    await _linkService.updateLocation(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      address: _currentAddress,
      batteryLevel: batteryLevel,
      isCharging: isCharging,
      accuracy: _currentPosition!.accuracy,
    );
  }

  Future<void> _loadLinkedLocations() async {
    final locations = await _linkService.getLinkedLocations();
    
    if (mounted && !_isDisposed) {
      setState(() {
        // ✅ FILTRAR: Solo usuarios bloqueados
        _linkedLocations = locations.where((user) {
          return user.isLocked == true;
        }).toList();
      });
      _updateMarkers();
    }
  }

  // ✅ MÉTODO CORREGIDO
  Future<void> _getCurrentLocation() async {
    if (_isDisposed) return;
    
    try {
      // ✅ NO cambiar _isLoading aquí para que el mapa siga visible
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Servicios de ubicación deshabilitados');
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permiso denegado');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Ve a Configuración > JCA > Ubicación');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (_isDisposed || !mounted) return;

      setState(() {
        _currentPosition = position;
      });

      await _getAddressFromCoordinates(position);
      await _updateMyLocation();
      await _loadLinkedLocations();

      // ✅ Mover cámara solo si el mapa está listo
      if (_isMapReady && _mapController != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!_isDisposed && mounted) {
          _mapController!.move(
            LatLng(position.latitude, position.longitude),
            15,
          );
        }
      }

      // ✅ Iniciar actualizaciones automáticas
      _startLocationUpdates();

    } catch (e) {
      print('❌ Error obteniendo ubicación: $e');
      if (_isDisposed || !mounted) return;
      
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }
  
  Future<void> _getAddressFromCoordinates(Position position) async {
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

        if (mounted) {
          setState(() {
            _currentAddress = parts.isNotEmpty 
                ? parts.join(', ') 
                : data['display_name'];
          });
        }
      }
    } catch (e) {
      print('Error obteniendo dirección: $e');
      if (mounted) {
        setState(() {
          _currentAddress = 'Lat: ${position.latitude.toStringAsFixed(6)}, '
                           'Lng: ${position.longitude.toStringAsFixed(6)}';
        });
      }
    }
  }

  Future<void> _loadEmergencyPlaces(Position position) async {
    if (_isDisposed) return;
    
    try {
      const radiusMeters = 3000;
      
      final query = '''
        [out:json][timeout:25];
        (
          node["amenity"="police"](around:$radiusMeters,${position.latitude},${position.longitude});
          node["amenity"="hospital"](around:$radiusMeters,${position.latitude},${position.longitude});
          node["amenity"="clinic"](around:$radiusMeters,${position.latitude},${position.longitude});
          node["amenity"="fire_station"](around:$radiusMeters,${position.latitude},${position.longitude});
          node["amenity"="townhall"](around:$radiusMeters,${position.latitude},${position.longitude});
          node["amenity"="pharmacy"](around:$radiusMeters,${position.latitude},${position.longitude});
          
          way["amenity"="police"](around:$radiusMeters,${position.latitude},${position.longitude});
          way["amenity"="hospital"](around:$radiusMeters,${position.latitude},${position.longitude});
          way["amenity"="clinic"](around:$radiusMeters,${position.latitude},${position.longitude});
          way["amenity"="fire_station"](around:$radiusMeters,${position.latitude},${position.longitude});
          way["amenity"="townhall"](around:$radiusMeters,${position.latitude},${position.longitude});
          way["amenity"="pharmacy"](around:$radiusMeters,${position.latitude},${position.longitude});
        );
        out center;
      ''';

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        _emergencyMarkers.clear();

        for (var element in elements) {
          final tags = element['tags'] ?? {};
          final amenity = tags['amenity'];
          
          if (!_placeTypes.containsKey(amenity) || !_placeTypes[amenity]!) {
            continue;
          }

          double lat, lon;
          if (element['type'] == 'node') {
            lat = element['lat'];
            lon = element['lon'];
          } else {
            lat = element['center']['lat'];
            lon = element['center']['lon'];
          }

          final name = tags['name'] ?? _getDefaultName(amenity);
          
          _emergencyMarkers.add(_createPlaceMarker(
            LatLng(lat, lon),
            name,
            amenity,
          ));
        }
      }

    } catch (e) {
      print('Error cargando lugares: $e');
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _updateMarkers() {
    if (_currentPosition == null) return;
    
    _userMarkers.clear();
    
    _addUserMarker(_currentPosition!);
    
    for (var linkedUser in _linkedLocations) {
      if (linkedUser.latitude != null && linkedUser.longitude != null) {
        _addLinkedUserMarker(linkedUser);
      }
    }
    
    if (mounted) setState(() {});
  }

  String _getDefaultName(String type) {
    switch (type) {
      case 'police': return 'Estación de Policía';
      case 'hospital': return 'Hospital';
      case 'clinic': return 'Clínica';
      case 'fire_station': return 'Estación de Bomberos';
      case 'townhall': return 'Alcaldía';
      case 'pharmacy': return 'Farmacia';
      default: return 'Lugar';
    }
  }

  void _addUserMarker(Position position) {
    _userMarkers.add(
      Marker(
        point: LatLng(position.latitude, position.longitude),
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () => _showUserLocationInfo(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.6),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Text(
                  'Tú',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addLinkedUserMarker(LinkedUserModel user) {
    _userMarkers.add(
      Marker(
        point: LatLng(user.latitude!, user.longitude!),
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () => _showLinkedUserInfo(user),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.6),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_pin,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxWidth: 70),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  user.nombre.split(' ').first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserLocationInfo() {
    if (_currentPosition == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_pin_circle,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Tu Ubicación Actual',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            
            if (_currentAddress != null) ...[
              const Row(
                children: [
                  Icon(Icons.location_on, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Dirección',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  _currentAddress!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            const Row(
              children: [
                Icon(Icons.place, color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 8),
                Text(
                  'Coordenadas GPS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latitud: ${_currentPosition!.latitude.toStringAsFixed(7)}°',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Longitud: ${_currentPosition!.longitude.toStringAsFixed(7)}°',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            const Row(
              children: [
                Icon(Icons.gps_fixed, color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 8),
                Text(
                  'Precisión',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                '±${_currentPosition!.accuracy.toStringAsFixed(1)} metros',
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkedUserInfo(LinkedUserModel user) {
    final distance = _currentPosition != null
        ? Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            user.latitude!,
            user.longitude!,
          )
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_pin,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JC-ID: ${user.jcId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            
            if (distance != null) ...[
              const Row(
                children: [
                  Icon(Icons.straighten, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Distancia',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  distance >= 1000
                      ? '${(distance / 1000).toStringAsFixed(2)} km'
                      : '${distance.toStringAsFixed(0)} metros',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            if (user.address != null) ...[
              const Row(
                children: [
                  Icon(Icons.location_on, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Dirección',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  user.address!,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            const Row(
              children: [
                Icon(Icons.place, color: Color(0xFF10B981), size: 20),
                SizedBox(width: 8),
                Text(
                  'Coordenadas GPS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latitud: ${user.latitude!.toStringAsFixed(7)}°',
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Longitud: ${user.longitude!.toStringAsFixed(7)}°',
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            
            if (user.batteryLevel != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    user.isCharging == true 
                        ? Icons.battery_charging_full 
                        : Icons.battery_std,
                    color: const Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Batería',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  '${user.batteryLevel}% ${user.isCharging == true ? "(Cargando)" : ""}',
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ],
            
            if (user.accuracy != null) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.gps_fixed, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Precisión',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  '±${user.accuracy!.toStringAsFixed(1)} metros',
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ],
            
            if (user.timestamp != null) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.access_time, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Última actualización',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  _formatTimestamp(user.timestamp!),
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openInGoogleMaps(user.latitude!, user.longitude!),
                icon: const Icon(Icons.map),
                label: const Text('Abrir en Google Maps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'Hace ${difference.inSeconds} segundos';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} horas';
    } else {
      return 'Hace ${difference.inDays} días';
    }
  }

  Future<void> _openInGoogleMaps(double lat, double lon) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps')),
        );
      }
    }
  }

  Marker _createPlaceMarker(LatLng position, String name, String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'police':
        icon = Icons.local_police;
        color = const Color(0xFF3B82F6);
        break;
      case 'hospital':
        icon = Icons.local_hospital;
        color = const Color(0xFFEF4444);
        break;
      case 'clinic':
        icon = Icons.medical_services;
        color = const Color(0xFFF97316);
        break;
      case 'fire_station':
        icon = Icons.fire_truck;
        color = const Color(0xFFDC2626);
        break;
      case 'townhall':
        icon = Icons.account_balance;
        color = const Color(0xFF8B5CF6);
        break;
      case 'pharmacy':
        icon = Icons.local_pharmacy;
        color = const Color(0xFF10B981);
        break;
      default:
        icon = Icons.place;
        color = Colors.grey;
    }

    return Marker(
      point: position,
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showPlaceInfo(name, type, position),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _showPlaceInfo(String name, String type, LatLng position) {
    final distance = _currentPosition != null
        ? Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            position.latitude,
            position.longitude,
          )
        : null;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getColorForType(type),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForType(type),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            
            Row(
              children: [
                Icon(
                  Icons.category,
                  color: _getColorForType(type),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Tipo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                _getDefaultName(type),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            if (distance != null) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.straighten, color: Colors.grey, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Distancia',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  distance >= 1000
                      ? '${(distance / 1000).toStringAsFixed(2)} km de tu ubicación'
                      : '${distance.toStringAsFixed(0)} metros de tu ubicación',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.place, color: Colors.grey, size: 20),
                SizedBox(width: 8),
                Text(
                  'Coordenadas',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lat: ${position.latitude.toStringAsFixed(6)}°',
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lng: ${position.longitude.toStringAsFixed(6)}°',
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openInGoogleMaps(position.latitude, position.longitude),
                icon: const Icon(Icons.directions),
                label: const Text('Cómo llegar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getColorForType(type),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'police':
        return Icons.local_police;
      case 'hospital':
        return Icons.local_hospital;
      case 'clinic':
        return Icons.medical_services;
      case 'fire_station':
        return Icons.fire_truck;
      case 'townhall':
        return Icons.account_balance;
      case 'pharmacy':
        return Icons.local_pharmacy;
      default:
        return Icons.place;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'police':
        return const Color(0xFF3B82F6);
      case 'hospital':
        return const Color(0xFFEF4444);
      case 'clinic':
        return const Color(0xFFF97316);
      case 'fire_station':
        return const Color(0xFFDC2626);
      case 'townhall':
        return const Color(0xFF8B5CF6);
      case 'pharmacy':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers),
            tooltip: 'Estilo de mapa',
            onSelected: (String style) {
              setState(() {
                _currentStyle = style;
              });
            },
            itemBuilder: (BuildContext context) {
              return _mapStyles.keys.map((String style) {
                return PopupMenuItem<String>(
                  value: style,
                  child: Row(
                    children: [
                      Icon(
                        _currentStyle == style
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: const Color(0xFF2563EB),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(style),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtros',
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lugares de emergencia',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._placeTypes.keys.map((type) {
                        return CheckboxListTile(
                          title: Text(
                            _getDefaultName(type),
                            style: const TextStyle(fontSize: 13),
                          ),
                          value: _placeTypes[type],
                          dense: true,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (bool? value) {
                            setState(() {
                              _placeTypes[type] = value ?? true;
                            });
                            if (_currentPosition != null) {
                              _loadEmergencyPlaces(_currentPosition!);
                            }
                            Navigator.pop(context);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2563EB)),
                  SizedBox(height: 20),
                  Text(
                    'Cargando mapa...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar la ubicación',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentPosition != null
                            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                            : const LatLng(4.5339, -75.6811),
                        initialZoom: 13.0,
                        onMapReady: () {
                          print('✅ Mapa listo para usar');
                          setState(() {
                            _isMapReady = true;
                          });
                          // ✅ Ahora sí obtener la ubicación
                          _getCurrentLocation();
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _mapStyles[_currentStyle],
                          userAgentPackageName: 'com.jca.app',
                        ),
                        MarkerLayer(markers: _emergencyMarkers),
                        MarkerLayer(markers: _userMarkers),
                      ],
                    ),
                    
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: FloatingActionButton(
                        onPressed: () {
                          if (_currentPosition != null && _mapController != null && _isMapReady) {
                            _mapController!.move(
                              LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                              15,
                            );
                          }
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.my_location,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    
                    if (_linkedLocations.isNotEmpty)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.people,
                                color: Color(0xFF10B981),
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_linkedLocations.length} vinculado${_linkedLocations.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: _currentPosition != null && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _getCurrentLocation,
              backgroundColor: const Color(0xFF2563EB),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Actualizar',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locationUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}