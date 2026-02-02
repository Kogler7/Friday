/// 想法记录中的一条消息（自己和自己聊）
class ChatMessage {
  final String id;
  final DateTime createdAt;
  final String content;
  /// 隐藏后仅在开发者模式下展示
  final bool isHidden;
  /// 引用消息 id，null 表示未引用
  final String? quotedMessageId;
  /// 引用内容摘要，用于展示
  final String? quotedContent;

  const ChatMessage({
    required this.id,
    required this.createdAt,
    required this.content,
    this.isHidden = false,
    this.quotedMessageId,
    this.quotedContent,
  });

  ChatMessage copyWith({
    String? id,
    DateTime? createdAt,
    String? content,
    bool? isHidden,
    String? quotedMessageId,
    String? quotedContent,
    bool clearQuoted = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      content: content ?? this.content,
      isHidden: isHidden ?? this.isHidden,
      quotedMessageId: clearQuoted ? null : (quotedMessageId ?? this.quotedMessageId),
      quotedContent: clearQuoted ? null : (quotedContent ?? this.quotedContent),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'content': content,
        if (isHidden) 'isHidden': isHidden,
        if (quotedMessageId != null) 'quotedMessageId': quotedMessageId,
        if (quotedContent != null) 'quotedContent': quotedContent,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      content: json['content'] as String,
      isHidden: json['isHidden'] as bool? ?? false,
      quotedMessageId: json['quotedMessageId'] as String?,
      quotedContent: json['quotedContent'] as String?,
    );
  }
}
