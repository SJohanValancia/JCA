// user_model.dart
class DeudaInfo {
  final double deudaTotal;
  final double deudaRestante;
  final int cuotasPagadas;
  final int cuotasPendientes;
  final double montoCuota;
  final DateTime? proximoPago;
  final DateTime? ultimoPago;

  DeudaInfo({
    required this.deudaTotal,
    required this.deudaRestante,
    required this.cuotasPagadas,
    required this.cuotasPendientes,
    required this.montoCuota,
    this.proximoPago,
    this.ultimoPago,
  });

  factory DeudaInfo.fromJson(Map<String, dynamic> json) {
    return DeudaInfo(
      deudaTotal: (json['deudaTotal'] ?? 0).toDouble(),
      deudaRestante: (json['deudaRestante'] ?? 0).toDouble(),
      cuotasPagadas: json['cuotasPagadas'] ?? 0,
      cuotasPendientes: json['cuotasPendientes'] ?? 0,
      montoCuota: (json['montoCuota'] ?? 0).toDouble(),
      proximoPago: json['proximoPago'] != null 
          ? DateTime.parse(json['proximoPago']) 
          : null,
      ultimoPago: json['ultimoPago'] != null 
          ? DateTime.parse(json['ultimoPago']) 
          : null,
    );
  }
}

class UserModel {
  final String id;
  final String nombre;
  final String telefono;
  final String usuario;
  final String jcId;
  final String rol;
  final DeudaInfo? deudaInfo;

  UserModel({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.usuario,
    required this.jcId,
    required this.rol,
    this.deudaInfo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      telefono: json['telefono'] ?? '',
      usuario: json['usuario'] ?? '',
      jcId: json['jcId'] ?? 'N/A',
      rol: json['rol'] ?? 'dueno', // ✅ Sin ñ
      deudaInfo: json['deudaInfo'] != null 
          ? DeudaInfo.fromJson(json['deudaInfo'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'telefono': telefono,
      'usuario': usuario,
      'jcId': jcId,
      'rol': rol,
    };
  }

  // ✅ Helper para verificar rol (sin ñ)
  bool get isDueno => rol == 'dueno';
  bool get isVendedor => rol == 'vendedor';
}