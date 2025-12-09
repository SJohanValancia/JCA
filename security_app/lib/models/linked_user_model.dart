class LinkedUserModel {
  final String id;
  final String nombre;
  final String usuario;
  final String jcId;
  final double? latitude;
  final double? longitude;
  final String? address;
  final int? batteryLevel;
  final bool? isCharging;
  final double? accuracy;
  final DateTime? timestamp;

  LinkedUserModel({
    required this.id,
    required this.nombre,
    required this.usuario,
    required this.jcId,
    this.latitude,
    this.longitude,
    this.address,
    this.batteryLevel,
    this.isCharging,
    this.accuracy,
    this.timestamp,
  });

  factory LinkedUserModel.fromJson(Map<String, dynamic> json) {
    return LinkedUserModel(
      id: json['userId']?['_id'] ?? json['_id'] ?? '',
      nombre: json['userId']?['nombre'] ?? json['nombre'] ?? '',
      usuario: json['userId']?['usuario'] ?? json['usuario'] ?? '',
      jcId: json['userId']?['jcId'] ?? json['jcId'] ?? '',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      address: json['address'],
      batteryLevel: json['batteryLevel'],
      isCharging: json['isCharging'],
      accuracy: json['accuracy']?.toDouble(),
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : null,
    );
  }
}

class LinkRequest {
  final String id;
  final String nombre;
  final String usuario;
  final String jcId;
  final DateTime requestedAt;

  LinkRequest({
    required this.id,
    required this.nombre,
    required this.usuario,
    required this.jcId,
    required this.requestedAt,
  });

  factory LinkRequest.fromJson(Map<String, dynamic> json) {
    return LinkRequest(
      id: json['_id'],
      nombre: json['userId']['nombre'],
      usuario: json['userId']['usuario'],
      jcId: json['userId']['jcId'],
      requestedAt: DateTime.parse(json['requestedAt']),
    );
  }
}