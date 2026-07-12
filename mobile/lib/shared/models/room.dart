class Room {
  const Room({
    required this.id,
    required this.homeId,
    required this.name,
    this.description,
    this.sortOrder = 0,
    required this.createdByUserId,
    this.archivedAt,
  });

  final String id;
  final String homeId;
  final String name;
  final String? description;
  final int sortOrder;
  final String createdByUserId;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdByUserId: json['created_by_user_id'] as String,
      archivedAt: json['archived_at'] != null
          ? DateTime.tryParse(json['archived_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson({required String createdByUserId}) => {
        'home_id': homeId,
        'name': name,
        'description': description,
        'sort_order': sortOrder,
        'created_by_user_id': createdByUserId,
      };
}
