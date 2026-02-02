/// LLM Agent 模型，用于管理不同角色/用途的 AI 助手配置
class LlmAgent {
  final String id;
  final String name;
  /// 系统提示词，定义 Agent 的角色与行为
  final String? systemPrompt;
  /// 覆盖默认模型（为空则使用设置中的模型）
  final String? modelOverride;
  /// 描述，用于展示
  final String? description;
  /// 最长上下文字符数（用户+助手消息内容合计），超出从后向前截断；null 表示使用全局条数设置
  final int? maxContextChars;
  final DateTime createdAt;

  const LlmAgent({
    required this.id,
    required this.name,
    this.systemPrompt,
    this.modelOverride,
    this.description,
    this.maxContextChars,
    required this.createdAt,
  });

  LlmAgent copyWith({
    String? id,
    String? name,
    String? systemPrompt,
    String? modelOverride,
    String? description,
    int? maxContextChars,
    DateTime? createdAt,
    bool clearMaxContextChars = false,
  }) {
    return LlmAgent(
      id: id ?? this.id,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      modelOverride: modelOverride ?? this.modelOverride,
      description: description ?? this.description,
      maxContextChars: clearMaxContextChars ? null : (maxContextChars ?? this.maxContextChars),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (systemPrompt != null) 'systemPrompt': systemPrompt,
        if (modelOverride != null) 'modelOverride': modelOverride,
        if (description != null) 'description': description,
        if (maxContextChars != null) 'maxContextChars': maxContextChars,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LlmAgent.fromJson(Map<String, dynamic> json) {
    return LlmAgent(
      id: json['id'] as String,
      name: json['name'] as String,
      systemPrompt: json['systemPrompt'] as String?,
      modelOverride: json['modelOverride'] as String?,
      description: json['description'] as String?,
      maxContextChars: (json['maxContextChars'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
