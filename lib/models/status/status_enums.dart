// 活动性质与状态指标枚举

/// 精力使用
enum EnergyUsage {
  recovery,   // 恢复
  normal,     // 正常
  consumption,// 消耗
  overdraft,  // 透支
}

/// 体力使用
enum PhysicalUsage {
  recovery,
  normal,
  consumption,
  overdraft,
}

/// 活动动机
enum ActivityMotivation {
  internal,   // 内源/私事
  external,   // 外源/公事
  objective,  // 客观占用
}

/// 产出定性
enum OutputQuality {
  loss,       // 损耗
  neutral,    // 中性
  accumulation, // 积累
  investment, // 投资
}

/// 情绪状态
enum EmotionalState {
  anxious,    // 焦虑
  average,    // 一般
  calm,       // 平静
  excited,    // 兴奋
}

/// 精力状态
enum EnergyState {
  exhausted,  // 疲惫
  poor,       // 较差
  average,    // 一般
  good,       // 良好
}

/// 生理状态
enum PhysicalState {
  low,        // 低下
  suboptimal, // 欠佳
  normal,     // 正常
  good,       // 良好
}

/// 注意力状态
enum AttentionState {
  distracted, // 涣散
  average,    // 一般
  focused,    // 专注
  flow,       // 心流
}

extension EnergyUsageExt on EnergyUsage {
  String get displayName => switch (this) {
    EnergyUsage.recovery => '恢复',
    EnergyUsage.normal => '正常',
    EnergyUsage.consumption => '消耗',
    EnergyUsage.overdraft => '透支',
  };
}

extension PhysicalUsageExt on PhysicalUsage {
  String get displayName => switch (this) {
    PhysicalUsage.recovery => '恢复',
    PhysicalUsage.normal => '正常',
    PhysicalUsage.consumption => '消耗',
    PhysicalUsage.overdraft => '透支',
  };
}

extension ActivityMotivationExt on ActivityMotivation {
  String get displayName => switch (this) {
    ActivityMotivation.internal => '内源/私事',
    ActivityMotivation.external => '外源/公事',
    ActivityMotivation.objective => '客观占用',
  };
}

extension OutputQualityExt on OutputQuality {
  String get displayName => switch (this) {
    OutputQuality.loss => '损耗',
    OutputQuality.neutral => '中性',
    OutputQuality.accumulation => '积累',
    OutputQuality.investment => '投资',
  };
}

extension EmotionalStateExt on EmotionalState {
  String get displayName => switch (this) {
    EmotionalState.anxious => '焦虑',
    EmotionalState.average => '一般',
    EmotionalState.calm => '平静',
    EmotionalState.excited => '兴奋',
  };
}

extension EnergyStateExt on EnergyState {
  String get displayName => switch (this) {
    EnergyState.exhausted => '疲惫',
    EnergyState.poor => '较差',
    EnergyState.average => '一般',
    EnergyState.good => '良好',
  };
}

extension PhysicalStateExt on PhysicalState {
  String get displayName => switch (this) {
    PhysicalState.low => '低下',
    PhysicalState.suboptimal => '欠佳',
    PhysicalState.normal => '正常',
    PhysicalState.good => '良好',
  };
}

extension AttentionStateExt on AttentionState {
  String get displayName => switch (this) {
    AttentionState.distracted => '涣散',
    AttentionState.average => '一般',
    AttentionState.focused => '专注',
    AttentionState.flow => '心流',
  };
}
