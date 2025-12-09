class UserModel {
  final String id;
  final String nombre;
  final String telefono;
  final String usuario;
  final String jcId; // 🆕

  UserModel({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.usuario,
    required this.jcId, // 🆕
  });

factory UserModel.fromJson(Map<String, dynamic> json) {
  return UserModel(
    id: json['id'] ?? '',
    nombre: json['nombre'] ?? '',
    telefono: json['telefono'] ?? '',
    usuario: json['usuario'] ?? '',
    jcId: json['jcId'] ?? 'N/A', // ✅ Cambia '' por 'N/A' para debugging
  );
}
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'telefono': telefono,
      'usuario': usuario,
      'jcId': jcId, // 🆕
    };
  }
}