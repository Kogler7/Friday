import 'activity_state.dart';

/// 某一小时的状态记录（小时粒度，如 2025-01-30 14:00 表示 14:00~15:00）
class HourlyRecord {
  final DateTime hourStart; // 该小时的开始时间（分秒为 0）
  final ActivityState state;

  const HourlyRecord({
    required this.hourStart,
    required this.state,
  });

  String get dateKey {
    return '${hourStart.year}-${hourStart.month.toString().padLeft(2, '0')}-${hourStart.day.toString().padLeft(2, '0')}';
  }

  int get hourOfDay => hourStart.hour;

  /// 展示用时间范围（支持整点 1 小时或开发模式 2 分钟槽）
  String get displayTimeRange {
    final h = hourStart.hour;
    final m = hourStart.minute;
    String pad(int n) => n < 10 ? '0$n' : '$n';
    if (m == 0) {
      return '${pad(h)}:00 - ${pad((h + 1) % 24)}:00';
    }
    final endM = (m + 2) % 60;
    final endH = (h + (m + 2) ~/ 60) % 24;
    return '${pad(h)}:${pad(m)} - ${pad(endH)}:${pad(endM)}';
  }

  Map<String, dynamic> toJson() => {
        'hourStart': hourStart.toIso8601String(),
        'state': state.value,
      };

  factory HourlyRecord.fromJson(Map<String, dynamic> json) {
    return HourlyRecord(
      hourStart: DateTime.parse(json['hourStart'] as String),
      state: ActivityStateExtension.fromValue(json['state'] as String),
    );
  }
}
