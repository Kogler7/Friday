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
  final bool isStarred;
  /// Material Icons codePoint，null 表示默认气泡图标
  final int? iconCodePoint;
  /// 列表项图标/强调色，Color.value，null 表示使用主题色
  final int? colorValue;

  const IdeaSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.isLocked = false,
    this.isHidden = false,
    this.isStarred = false,
    this.iconCodePoint,
    this.colorValue,
  });

  IdeaSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    bool? isLocked,
    bool? isHidden,
    bool? isStarred,
    int? iconCodePoint,
    int? colorValue,
    bool clearIconCodePoint = false,
    bool clearColorValue = false,
  }) {
    return IdeaSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      isLocked: isLocked ?? this.isLocked,
      isHidden: isHidden ?? this.isHidden,
      isStarred: isStarred ?? this.isStarred,
      iconCodePoint: clearIconCodePoint ? null : (iconCodePoint ?? this.iconCodePoint),
      colorValue: clearColorValue ? null : (colorValue ?? this.colorValue),
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
        'isStarred': isStarred,
        if (iconCodePoint != null) 'iconCodePoint': iconCodePoint,
        if (colorValue != null) 'colorValue': colorValue,
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
      isStarred: json['isStarred'] as bool? ?? false,
      iconCodePoint: json['iconCodePoint'] as int?,
      colorValue: json['colorValue'] as int?,
    );
  }
}
