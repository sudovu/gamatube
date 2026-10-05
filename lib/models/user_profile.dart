class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? tokenExpiresAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.accessToken,
    this.refreshToken,
    this.tokenExpiresAt,
  });

  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;
  bool get isTokenExpired =>
      tokenExpiresAt != null && DateTime.now().isAfter(tokenExpiresAt!);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenExpiresAt': tokenExpiresAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      tokenExpiresAt: json['tokenExpiresAt'] != null
          ? DateTime.tryParse(json['tokenExpiresAt'] as String)
          : null,
    );
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiresAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
    );
  }
}
