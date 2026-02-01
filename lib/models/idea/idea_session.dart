import 'chat_message.dart';

/// 想法会话：多会话管理下的单次会话
class IdeaSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final bool isLocked;
  final bool isHidden;

  const IdeaSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.isLocked = false,
    this.isHidden = false,
  });

  IdeaSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    bool? isLocked,
    bool? isHidden,
  }) {
    return IdeaSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      isLocked: isLocked ?? this.isLocked,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((e) => e.toJson()).toList(),
        'isLocked': isLocked,
        'isHidden': isHidden,
      };

  factory IdeaSession.fromJson(Map<String, dynamic> json) {
    final list = json['messages'] as List<dynamic>? ?? [];
    return IdeaSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? '未命名会话',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      messages: list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      isLocked: json['isLocked'] as bool? ?? false,
      isHidden: json['isHidden'] as bool? ?? false,
    );
  }
}
