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
  final DateTime createdAt;

  const LlmAgent({
    required this.id,
    required this.name,
    this.systemPrompt,
    this.modelOverride,
    this.description,
    required this.createdAt,
  });

  LlmAgent copyWith({
    String? id,
    String? name,
    String? systemPrompt,
    String? modelOverride,
    String? description,
    DateTime? createdAt,
  }) {
    return LlmAgent(
      id: id ?? this.id,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      modelOverride: modelOverride ?? this.modelOverride,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (systemPrompt != null) 'systemPrompt': systemPrompt,
        if (modelOverride != null) 'modelOverride': modelOverride,
        if (description != null) 'description': description,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LlmAgent.fromJson(Map<String, dynamic> json) {
    return LlmAgent(
      id: json['id'] as String,
      name: json['name'] as String,
      systemPrompt: json['systemPrompt'] as String?,
      modelOverride: json['modelOverride'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
