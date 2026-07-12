class Profile {
  const Profile({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.preferredCurrency = 'USD',
    this.preferredLanguage = 'en',
    this.timezone = 'UTC',
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final String preferredCurrency;
  final String preferredLanguage;
  final String timezone;

  String get greetingName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name.split(' ').first;
    final mail = email?.trim();
    if (mail != null && mail.contains('@')) return mail.split('@').first;
    return 'there';
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      preferredCurrency: (json['preferred_currency'] as String?) ?? 'USD',
      preferredLanguage: (json['preferred_language'] as String?) ?? 'en',
      timezone: (json['timezone'] as String?) ?? 'UTC',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'preferred_currency': preferredCurrency,
        'preferred_language': preferredLanguage,
        'timezone': timezone,
      };
}
