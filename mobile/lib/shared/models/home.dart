import 'enums.dart';

class Home {
  const Home({
    required this.id,
    required this.name,
    this.description,
    this.remarks,
    this.coverImageId,
    this.addressText,
    this.residingSince,
    this.timezone = 'UTC',
    this.defaultCurrency = 'USD',
    required this.createdByUserId,
    this.updatedBy,
    this.archivedAt,
    this.myRole,
  });

  final String id;
  final String name;
  final String? description;
  final String? remarks;
  final String? coverImageId;
  final String? addressText;
  final DateTime? residingSince;
  final String timezone;
  final String defaultCurrency;
  final String createdByUserId;
  final String? updatedBy;
  final DateTime? archivedAt;
  final HomeRole? myRole;

  bool get isArchived => archivedAt != null;

  /// Derived residence age; never persisted.
  String? residenceDurationLabel([DateTime? now]) {
    final start = residingSince;
    if (start == null) return null;
    final end = now ?? DateTime.now();
    var years = end.year - start.year;
    var months = end.month - start.month;
    if (end.day < start.day) months -= 1;
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    if (years < 0) return null;
    if (years == 0 && months == 0) {
      final days = end.difference(start).inDays;
      if (days <= 0) return 'Living here since today';
      if (days == 1) return 'Living here for 1 day';
      return 'Living here for $days days';
    }
    final parts = <String>[];
    if (years > 0) parts.add(years == 1 ? '1 year' : '$years years');
    if (months > 0) parts.add(months == 1 ? '1 month' : '$months months');
    return 'Living here for ${parts.join(', ')}';
  }

  Home copyWith({
    String? name,
    String? description,
    String? remarks,
    String? coverImageId,
    String? addressText,
    DateTime? residingSince,
    String? timezone,
    String? defaultCurrency,
    String? updatedBy,
    DateTime? archivedAt,
    HomeRole? myRole,
    bool clearDescription = false,
    bool clearRemarks = false,
    bool clearCoverImageId = false,
    bool clearAddressText = false,
    bool clearResidingSince = false,
    bool clearArchivedAt = false,
  }) {
    return Home(
      id: id,
      name: name ?? this.name,
      description:
          clearDescription ? null : (description ?? this.description),
      remarks: clearRemarks ? null : (remarks ?? this.remarks),
      coverImageId:
          clearCoverImageId ? null : (coverImageId ?? this.coverImageId),
      addressText:
          clearAddressText ? null : (addressText ?? this.addressText),
      residingSince:
          clearResidingSince ? null : (residingSince ?? this.residingSince),
      timezone: timezone ?? this.timezone,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      createdByUserId: createdByUserId,
      updatedBy: updatedBy ?? this.updatedBy,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      myRole: myRole ?? this.myRole,
    );
  }

  factory Home.fromJson(Map<String, dynamic> json, {HomeRole? myRole}) {
    DateTime? residingSince;
    final rawSince = json['residing_since'];
    if (rawSince is String && rawSince.isNotEmpty) {
      residingSince = DateTime.tryParse(rawSince);
    }

    return Home(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      remarks: json['remarks'] as String?,
      coverImageId: json['cover_image_id'] as String?,
      addressText: json['address_text'] as String?,
      residingSince: residingSince,
      timezone: (json['timezone'] as String?) ?? 'UTC',
      defaultCurrency: (json['default_currency'] as String?) ?? 'USD',
      createdByUserId: json['created_by_user_id'] as String,
      updatedBy: json['updated_by'] as String?,
      archivedAt: json['archived_at'] != null
          ? DateTime.tryParse(json['archived_at'] as String)
          : null,
      myRole: myRole,
    );
  }

  Map<String, dynamic> toInsertJson({required String createdByUserId}) => {
        'name': name,
        'description': description,
        'remarks': remarks,
        'address_text': addressText,
        'residing_since': residingSince?.toIso8601String().split('T').first,
        'timezone': timezone,
        'default_currency': defaultCurrency,
        'created_by_user_id': createdByUserId,
      };

  Map<String, dynamic> toUpdateJson() => {
        'name': name,
        'description': description,
        'remarks': remarks,
        'address_text': addressText,
        'residing_since': residingSince?.toIso8601String().split('T').first,
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
    this.avatarUrl,
  });

  final String id;
  final String homeId;
  final String userId;
  final HomeRole role;
  final MembershipStatus status;
  final DateTime? joinedAt;
  final String? displayName;
  final String? email;
  final String? avatarUrl;

  String get label =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : (email ?? userId);

  String get initials {
    final source = label.trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length >= 2 &&
        parts[0].isNotEmpty &&
        parts[1].isNotEmpty) {
      return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
    }
    return source[0].toUpperCase();
  }

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
      avatarUrl: profile?['avatar_url'] as String? ??
          json['avatar_url'] as String?,
    );
  }
}

class HomeDashboardStats {
  const HomeDashboardStats({
    required this.roomsCount,
    required this.baseFurnitureCount,
    required this.membersCount,
    required this.estimatedValue,
    required this.valueCurrency,
    this.valueIsPartial = true,
  });

  final int roomsCount;
  final int baseFurnitureCount;
  final int membersCount;
  final double estimatedValue;
  final String valueCurrency;
  final bool valueIsPartial;

  factory HomeDashboardStats.fromJson(Map<String, dynamic> json) {
    return HomeDashboardStats(
      roomsCount: (json['rooms_count'] as num?)?.toInt() ?? 0,
      baseFurnitureCount: (json['base_furniture_count'] as num?)?.toInt() ?? 0,
      membersCount: (json['members_count'] as num?)?.toInt() ?? 0,
      estimatedValue: (json['estimated_value'] as num?)?.toDouble() ?? 0,
      valueCurrency: (json['value_currency'] as String?) ?? 'USD',
      valueIsPartial: json['value_is_partial'] as bool? ?? true,
    );
  }
}
