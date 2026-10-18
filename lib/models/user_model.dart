class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final String status;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'KASIR',
      status: map['status'] ?? 'AKTIF',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'status': status,
    };
  }

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
}
