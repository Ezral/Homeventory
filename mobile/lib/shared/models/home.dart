import 'enums.dart';

class Home {
  const Home({
    required this.id,
    required this.name,
    this.description,
    this.coverImageId,
    this.addressText,
    this.timezone = 'UTC',
    this.defaultCurrency = 'USD',
    required this.createdByUserId,
    this.archivedAt,
    this.myRole,
  });

  final String id;
  final String name;
  final String? description;
  final String? coverImageId;
  final String? addressText;
  final String timezone;
  final String defaultCurrency;
  final String createdByUserId;
  final DateTime? archivedAt;
  final HomeRole? myRole;

  bool get isArchived => archivedAt != null;

  Home copyWith({
    String? name,
    String? description,
    String? coverImageId,
    String? addressText,
    String? timezone,
    String? defaultCurrency,
    DateTime? archivedAt,
    HomeRole? myRole,
    bool clearDescription = false,
    bool clearCoverImageId = false,
    bool clearAddressText = false,
    bool clearArchivedAt = false,
  }) {
    return Home(
      id: id,
      name: name ?? this.name,
      description:
          clearDescription ? null : (description ?? this.description),
      coverImageId:
          clearCoverImageId ? null : (coverImageId ?? this.coverImageId),
      addressText:
          clearAddressText ? null : (addressText ?? this.addressText),
      timezone: timezone ?? this.timezone,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      createdByUserId: createdByUserId,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      myRole: myRole ?? this.myRole,
    );
  }

  factory Home.fromJson(Map<String, dynamic> json, {HomeRole? myRole}) {
    return Home(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      coverImageId: json['cover_image_id'] as String?,
      addressText: json['address_text'] as String?,
      timezone: (json['timezone'] as String?) ?? 'UTC',
      defaultCurrency: (json['default_currency'] as String?) ?? 'USD',
      createdByUserId: json['created_by_user_id'] as String,
      archivedAt: json['archived_at'] != null
          ? DateTime.tryParse(json['archived_at'] as String)
          : null,
      myRole: myRole,
    );
  }

  Map<String, dynamic> toInsertJson({required String createdByUserId}) => {
        'name': name,
        'description': description,
        'address_text': addressText,
        'timezone': timezone,
        'default_currency': defaultCurrency,
        'created_by_user_id': createdByUserId,
      };

  Map<String, dynamic> toUpdateJson() => {
        'name': name,
        'description': description,
        'address_text': addressText,
        'timezone': timezone,
        'default_currency': defaultCurrency,
        if (coverImageId != null) 'cover_image_id': coverImageId,
      };
}

class HomeMember {
  const HomeMember({
    required this.id,
    required this.homeId,
    required this.userId,
    required this.role,
    required this.status,
    this.joinedAt,
    this.displayName,
    this.email,
  });

  final String id;
  final String homeId;
  final String userId;
  final HomeRole role;
  final MembershipStatus status;
  final DateTime? joinedAt;
  final String? displayName;
  final String? email;

  String get label =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : (email ?? userId);

  factory HomeMember.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? profile;
    final embedded = json['profiles'];
    if (embedded is Map) {
      profile = Map<String, dynamic>.from(embedded);
    }
    return HomeMember(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      userId: json['user_id'] as String,
      role: HomeRole.fromDb(json['role'] as String),
      status: MembershipStatus.fromDb(
        (json['status'] as String?) ?? MembershipStatus.active.dbValue,
      ),
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'] as String)
          : null,
      displayName: profile?['display_name'] as String? ??
          json['display_name'] as String?,
      email: profile?['email'] as String? ?? json['email'] as String?,
    );
  }
}
