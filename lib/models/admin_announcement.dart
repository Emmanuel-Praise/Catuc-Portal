class AdminAnnouncement {
  final int id;
  final String title;
  final String message;
  final String? imageUrl;
  final String priority;
  final String? targetRoles;
  final String createdAt;
  final String? expiresAt;
  final bool isActive;

  const AdminAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    this.imageUrl,
    this.priority = 'normal',
    this.targetRoles,
    this.createdAt = '',
    this.expiresAt,
    this.isActive = true,
  });

  factory AdminAnnouncement.fromJson(Map<String, dynamic> json) {
    return AdminAnnouncement(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      imageUrl: json['image_url']?.toString(),
      priority: (json['priority'] ?? 'normal').toString(),
      targetRoles: json['target_roles']?.toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      expiresAt: json['expires_at']?.toString(),
      isActive: json['is_active'] == 1 || json['is_active'] == '1' || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'image_url': imageUrl,
        'priority': priority,
        'target_roles': targetRoles,
        'created_at': createdAt,
        'expires_at': expiresAt,
        'is_active': isActive,
      };

  bool get isUrgent => priority == 'urgent' || priority == 'high';
}
