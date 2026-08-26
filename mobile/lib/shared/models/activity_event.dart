class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.homeId,
    this.actorUserId,
    required this.action,
    this.entityType,
    this.entityId,
    required this.summary,
    this.metadata = const {},
    required this.createdAt,
  });

  final String id;
  final String homeId;
  final String? actorUserId;
  final String action;
  final String? entityType;
  final String? entityId;
  final String summary;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['metadata'];
    return ActivityEvent(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      actorUserId: json['actor_user_id'] as String?,
      action: json['action'] as String,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      summary: json['summary'] as String,
      metadata: rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : const {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
