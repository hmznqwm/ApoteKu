class ActivityLogModel {
  final String id;
  final String userName;
  final String userRole;
  final String actionType; // 'TAMBAH', 'EDIT', 'HAPUS', 'REFUND'
  final String title;
  final String details;
  final String createdAt;

  ActivityLogModel({
    required this.id,
    required this.userName,
    required this.userRole,
    required this.actionType,
    required this.title,
    required this.details,
    required this.createdAt,
  });

  factory ActivityLogModel.fromMap(Map<String, dynamic> map) {
    return ActivityLogModel(
      id: map['id']?.toString() ?? '',
      userName: map['user_name']?.toString() ?? 'Sistem',
      userRole: map['user_role']?.toString() ?? 'KASIR',
      actionType: map['action_type']?.toString() ?? 'TAMBAH',
      title: map['title']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_name': userName,
      'user_role': userRole,
      'action_type': actionType,
      'title': title,
      'details': details,
      'created_at': createdAt,
    };
  }
}
