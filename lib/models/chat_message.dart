/// 想法记录中的一条消息（自己和自己聊）
class ChatMessage {
  final String id;
  final DateTime createdAt;
  final String content;

  const ChatMessage({
    required this.id,
    required this.createdAt,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'content': content,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      content: json['content'] as String,
    );
  }
}
