class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? tokenExpiresAt;

  final String? handle;
  final bool isIncognito;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.handle,
    this.accessToken,
    this.refreshToken,
    this.tokenExpiresAt,
    this.isIncognito = false,
  });

  String get displayName => name;

  String get displayHandle {
    if (handle != null && handle!.isNotEmpty) {
      return handle!.startsWith('@') ? handle! : '@$handle';
    }
    if (email.contains('@')) {
      return '@${email.split('@').first}';
    }
    return '@user';
  }

  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;
  bool get isTokenExpired =>
      tokenExpiresAt != null && DateTime.now().isAfter(tokenExpiresAt!);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'handle': handle ?? displayHandle,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenExpiresAt': tokenExpiresAt?.toIso8601String(),
      'isIncognito': isIncognito,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      handle: json['handle'] as String?,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      tokenExpiresAt: json['tokenExpiresAt'] != null
          ? DateTime.tryParse(json['tokenExpiresAt'] as String)
          : null,
      isIncognito: json['isIncognito'] as bool? ?? false,
    );
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? handle,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiresAt,
    bool? isIncognito,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      handle: handle ?? this.handle,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      isIncognito: isIncognito ?? this.isIncognito,
    );
  }
}
