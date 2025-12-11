// models/debt_config_model.dart
class DebtConfig {
  final double deudaTotal;
  final int numeroCuotas;
  final double montoCuota;
  final String modalidadPago; // 'diario', 'semanal', 'quincenal', 'mensual'
  final List<int> diasPago;
  final DateTime? proximoPago;
  final DateTime fechaInicio;

  DebtConfig({
    required this.deudaTotal,
    required this.numeroCuotas,
    required this.montoCuota,
    required this.modalidadPago,
    required this.diasPago,
    this.proximoPago,
    required this.fechaInicio,
  });

  factory DebtConfig.fromJson(Map<String, dynamic> json) {
    return DebtConfig(
      deudaTotal: (json['deudaTotal'] ?? 0).toDouble(),
      numeroCuotas: json['numeroCuotas'] ?? 0,
      montoCuota: (json['montoCuota'] ?? 0).toDouble(),
      modalidadPago: json['modalidadPago'] ?? 'mensual',
      diasPago: json['diasPago'] != null 
          ? List<int>.from(json['diasPago']) 
          : [],
      proximoPago: json['proximoPago'] != null 
          ? DateTime.parse(json['proximoPago']) 
          : null,
      fechaInicio: json['fechaInicio'] != null
          ? DateTime.parse(json['fechaInicio'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deudaTotal': deudaTotal,
      'numeroCuotas': numeroCuotas,
      'montoCuota': montoCuota,
      'modalidadPago': modalidadPago,
      'diasPago': diasPago,
      'proximoPago': proximoPago?.toIso8601String(),
      'fechaInicio': fechaInicio.toIso8601String(),
    };
  }
}