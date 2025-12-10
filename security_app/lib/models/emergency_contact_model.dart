class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final bool isEmergency;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.isEmergency = false,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      isEmergency: json['isEmergency'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'isEmergency': isEmergency,
    };
  }
}