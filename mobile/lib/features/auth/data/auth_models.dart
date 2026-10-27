class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.hasHealthProfile,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        role: json['role'] as String,
        hasHealthProfile: json['hasHealthProfile'] as bool? ?? false,
      );

  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool hasHealthProfile;
}

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) => TokenPair(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
}

/// Refresh bị từ chối (401/403) hoặc không lưu được refresh mới: phải đăng nhập lại.
class SessionExpiredException implements Exception {
  const SessionExpiredException([
    this.message = 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.',
  ]);

  final String message;

  @override
  String toString() => message;
}
