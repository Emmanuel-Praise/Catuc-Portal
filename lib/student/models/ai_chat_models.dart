class AIChatSession {
  final String id;
  final String title;
  final String aiType;
  final List<AIChatMessage> messages;
  final DateTime updatedAt;

  AIChatSession({
    required this.id,
    required this.title,
    required this.aiType,
    required this.messages,
    required this.updatedAt,
  });

  factory AIChatSession.fromJson(Map<String, dynamic> json) {
    return AIChatSession(
      id: json['id'] ?? '',
      title: json['title'] ?? 'New Chat',
      aiType: json['ai_type'] ?? 'brainstorm',
      messages: (json['messages'] as List? ?? [])
          .map((m) => AIChatMessage.fromJson(m))
          .toList(),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'ai_type': aiType,
    'messages': messages.map((m) => m.toJson()).toList(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class AIChatMessage {
  final String role;
  final String content;
  final bool isThinking;
  final DateTime? createdAt;

  AIChatMessage({
    required this.role,
    required this.content,
    this.isThinking = false,
    this.createdAt,
  });

  factory AIChatMessage.fromJson(Map<String, dynamic> json) {
    return AIChatMessage(
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      isThinking: json['is_thinking'] == true || json['isThinking'] == 'true',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'is_thinking': isThinking,
    'created_at': createdAt?.toIso8601String(),
  };
}
