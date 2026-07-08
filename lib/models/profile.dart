enum StaffRole { superAdmin, admin, client }

StaffRole roleFromString(String? value) {
  switch (value) {
    case 'super_admin':
      return StaffRole.superAdmin;
    case 'admin':
      return StaffRole.admin;
    default:
      return StaffRole.client;
  }
}

String roleToDb(StaffRole role) {
  switch (role) {
    case StaffRole.superAdmin:
      return 'super_admin';
    case StaffRole.admin:
      return 'admin';
    case StaffRole.client:
      return 'client';
  }
}

String roleToArabic(StaffRole role) {
  switch (role) {
    case StaffRole.superAdmin:
      return 'مشرف عام';
    case StaffRole.admin:
      return 'موظف';
    case StaffRole.client:
      return 'عميل';
  }
}

class Profile {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final StaffRole role;
  final String? avatarUrl;
  final int loginCount;
  final DateTime? lastLogin;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    required this.role,
    this.avatarUrl,
    this.loginCount = 0,
    this.lastLogin,
    required this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      role: roleFromString(map['role'] as String?),
      avatarUrl: map['avatar_url'] as String?,
      loginCount: (map['login_count'] as num?)?.toInt() ?? 0,
      lastLogin: map['last_login'] != null ? DateTime.tryParse(map['last_login'] as String)?.toLocal() : null,
      createdAt: (DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now()).toLocal(),
    );
  }

  bool get isStaff => role == StaffRole.admin || role == StaffRole.superAdmin;
}
