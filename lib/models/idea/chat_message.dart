/// 想法记录中的一条消息（用户或 LLM 助手）
class ChatMessage {
  final String id;
  final DateTime createdAt;
  final String content;
  /// 'user' | 'assistant'，默认 user
  final String role;
  /// 仅 assistant 消息：所 @ 的 Agent id
  final String? llmAgentId;
  /// 仅 assistant 消息：所 @ 的 Agent 名称，用于展示
  final String? llmAgentName;
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
    this.role = 'user',
    this.llmAgentId,
    this.llmAgentName,
    this.isHidden = false,
    this.quotedMessageId,
    this.quotedContent,
  });

  bool get isFromLlm => role == 'assistant';

  ChatMessage copyWith({
    String? id,
    DateTime? createdAt,
    String? content,
    String? role,
    String? llmAgentId,
    String? llmAgentName,
    bool? isHidden,
    String? quotedMessageId,
    String? quotedContent,
    bool clearQuoted = false,
    bool clearLlm = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      content: content ?? this.content,
      role: role ?? this.role,
      llmAgentId: clearLlm ? null : (llmAgentId ?? this.llmAgentId),
      llmAgentName: clearLlm ? null : (llmAgentName ?? this.llmAgentName),
      isHidden: isHidden ?? this.isHidden,
      quotedMessageId: clearQuoted ? null : (quotedMessageId ?? this.quotedMessageId),
      quotedContent: clearQuoted ? null : (quotedContent ?? this.quotedContent),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'content': content,
        if (role != 'user') 'role': role,
        if (llmAgentId != null) 'llmAgentId': llmAgentId,
        if (llmAgentName != null) 'llmAgentName': llmAgentName,
        if (isHidden) 'isHidden': isHidden,
        if (quotedMessageId != null) 'quotedMessageId': quotedMessageId,
        if (quotedContent != null) 'quotedContent': quotedContent,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      content: json['content'] as String,
      role: json['role'] as String? ?? 'user',
      llmAgentId: json['llmAgentId'] as String?,
      llmAgentName: json['llmAgentName'] as String?,
      isHidden: json['isHidden'] as bool? ?? false,
      quotedMessageId: json['quotedMessageId'] as String?,
      quotedContent: json['quotedContent'] as String?,
    );
  }
}
