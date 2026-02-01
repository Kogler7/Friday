import 'status_enums.dart';

/// 多维状态记录数据（活动性质、状态指标、活动标签）
class StatusRecordData {
  /// 精力使用
  final EnergyUsage? energyUsage;

  /// 体力使用
  final PhysicalUsage? physicalUsage;

  /// 活动动机
  final ActivityMotivation? activityMotivation;

  /// 产出定性
  final OutputQuality? outputQuality;

  /// 情绪状态
  final EmotionalState? emotionalState;

  /// 精力状态
  final EnergyState? energyState;

  /// 生理状态
  final PhysicalState? physicalState;

  /// 注意力状态
  final AttentionState? attentionState;

  /// 活动标签 id 列表（多选）
  final List<String> tagIds;

  const StatusRecordData({
    this.energyUsage,
    this.physicalUsage,
    this.activityMotivation,
    this.outputQuality,
    this.emotionalState,
    this.energyState,
    this.physicalState,
    this.attentionState,
    this.tagIds = const [],
  });

  StatusRecordData copyWith({
    EnergyUsage? energyUsage,
    PhysicalUsage? physicalUsage,
    ActivityMotivation? activityMotivation,
    OutputQuality? outputQuality,
    EmotionalState? emotionalState,
    EnergyState? energyState,
    PhysicalState? physicalState,
    AttentionState? attentionState,
    List<String>? tagIds,
  }) {
    return StatusRecordData(
      energyUsage: energyUsage ?? this.energyUsage,
      physicalUsage: physicalUsage ?? this.physicalUsage,
      activityMotivation: activityMotivation ?? this.activityMotivation,
      outputQuality: outputQuality ?? this.outputQuality,
      emotionalState: emotionalState ?? this.emotionalState,
      energyState: energyState ?? this.energyState,
      physicalState: physicalState ?? this.physicalState,
      attentionState: attentionState ?? this.attentionState,
      tagIds: tagIds ?? List.from(this.tagIds),
    );
  }

  /// 所有必填指标是否已填写（用于保存校验）
  bool get isComplete =>
      energyUsage != null &&
      physicalUsage != null &&
      activityMotivation != null &&
      outputQuality != null &&
      emotionalState != null &&
      energyState != null &&
      physicalState != null &&
      attentionState != null &&
      tagIds.isNotEmpty;

  /// 合并默认值：空字段用默认值填充
  static StatusRecordData withDefaults(StatusRecordData data) {
    return StatusRecordData(
      energyUsage: data.energyUsage ?? EnergyUsage.normal,
      physicalUsage: data.physicalUsage ?? PhysicalUsage.normal,
      activityMotivation: data.activityMotivation ?? ActivityMotivation.internal,
      outputQuality: data.outputQuality ?? OutputQuality.neutral,
      emotionalState: data.emotionalState ?? EmotionalState.average,
      energyState: data.energyState ?? EnergyState.average,
      physicalState: data.physicalState ?? PhysicalState.normal,
      attentionState: data.attentionState ?? AttentionState.average,
      tagIds: data.tagIds.isEmpty ? ['休息'] : data.tagIds,
    );
  }

  /// 是否有有效内容（至少有一个维度被填写）
  bool get isEmpty =>
      energyUsage == null &&
      physicalUsage == null &&
      activityMotivation == null &&
      outputQuality == null &&
      emotionalState == null &&
      energyState == null &&
      physicalState == null &&
      attentionState == null &&
      tagIds.isEmpty;

  /// 简短的摘要，用于列表展示（返回 tag id，展示时可用 ActivityTagStorage 解析）
  String get summary {
    if (tagIds.isNotEmpty) return tagIds.join(' · ');
    final parts = <String>[];
    if (energyUsage != null) parts.add(energyUsage!.displayName);
    if (physicalUsage != null) parts.add(physicalUsage!.displayName);
    if (activityMotivation != null) parts.add(activityMotivation!.displayName);
    if (outputQuality != null) parts.add(outputQuality!.displayName);
    if (emotionalState != null) parts.add(emotionalState!.displayName);
    if (energyState != null) parts.add(energyState!.displayName);
    if (physicalState != null) parts.add(physicalState!.displayName);
    if (attentionState != null) parts.add(attentionState!.displayName);
    return parts.isEmpty ? '—' : parts.take(3).join(' · ');
  }

  Map<String, dynamic> toJson() => {
        if (energyUsage != null) 'energyUsage': energyUsage!.name,
        if (physicalUsage != null) 'physicalUsage': physicalUsage!.name,
        if (activityMotivation != null)
          'activityMotivation': activityMotivation!.name,
        if (outputQuality != null) 'outputQuality': outputQuality!.name,
        if (emotionalState != null) 'emotionalState': emotionalState!.name,
        if (energyState != null) 'energyState': energyState!.name,
        if (physicalState != null) 'physicalState': physicalState!.name,
        if (attentionState != null) 'attentionState': attentionState!.name,
        'tagIds': tagIds,
      };

  factory StatusRecordData.fromJson(Map<String, dynamic> json) {
    final tagRaw = json['tagIds'] as List<dynamic>?;
    final tagList = tagRaw?.map((e) => e.toString()).toList() ?? [];
    return StatusRecordData(
      energyUsage: _parseEnum(json['energyUsage'], EnergyUsage.values),
      physicalUsage: _parseEnum(json['physicalUsage'], PhysicalUsage.values),
      activityMotivation:
          _parseEnum(json['activityMotivation'], ActivityMotivation.values),
      outputQuality: _parseEnum(json['outputQuality'], OutputQuality.values),
      emotionalState:
          _parseEnum(json['emotionalState'], EmotionalState.values),
      energyState: _parseEnum(json['energyState'], EnergyState.values),
      physicalState: _parseEnum(json['physicalState'], PhysicalState.values),
      attentionState:
          _parseEnum(json['attentionState'], AttentionState.values),
      tagIds: tagList,
    );
  }

  static T? _parseEnum<T>(dynamic value, List<T> values) {
    if (value == null) return null;
    final s = value.toString();
    try {
      return values.firstWhere((e) => e.toString().split('.').last == s);
    } catch (_) {
      return null;
    }
  }
}
