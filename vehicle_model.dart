class VehicleModel {
  final String id;
  final String userId;
  final String vehicleNumber;
  final String callNumber;
  final String whatsappNumber;
  final String token;
  final DateTime createdAt;

  VehicleModel({
    required this.id,
    required this.userId,
    required this.vehicleNumber,
    required this.callNumber,
    required this.whatsappNumber,
    required this.token,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'vehicleNumber': vehicleNumber,
      'callNumber': callNumber,
      'whatsappNumber': whatsappNumber,
      'token': token,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VehicleModel.fromMap(Map<String, dynamic> map) {
    return VehicleModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      vehicleNumber: map['vehicleNumber'] ?? '',
      callNumber: map['callNumber'] ?? '',
      whatsappNumber: map['whatsappNumber'] ?? '',
      token: map['token'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is String
              ? DateTime.parse(map['createdAt'])
              : (map['createdAt'] as dynamic).toDate() as DateTime)
          : DateTime.now(),
    );
  }
}