/// 过去一小时的状态类型
enum ActivityState {
  working,   // 工作
  resting,   // 休息
  entertainment, // 娱乐
}

extension ActivityStateExtension on ActivityState {
  String get displayName {
    switch (this) {
      case ActivityState.working:
        return '工作';
      case ActivityState.resting:
        return '休息';
      case ActivityState.entertainment:
        return '娱乐';
    }
  }

  String get value {
    switch (this) {
      case ActivityState.working:
        return 'working';
      case ActivityState.resting:
        return 'resting';
      case ActivityState.entertainment:
        return 'entertainment';
    }
  }

  static ActivityState fromValue(String value) {
    return ActivityState.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ActivityState.resting,
    );
  }
}
