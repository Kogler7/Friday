/// 预定免打扰：到点自动填充，不弹窗
class ScheduledDnd {
  final String id;
  final DateTime start;
  final DateTime end;
  final String presetId;
  /// 为 true 时每日循环，仅按 start/end 的时分判断
  final bool recurringDaily;

  const ScheduledDnd({
    required this.id,
    required this.start,
    required this.end,
    required this.presetId,
    this.recurringDaily = false,
  });

  /// 某时刻是否在此免打扰范围内
  bool contains(DateTime time) {
    if (recurringDaily) {
      final slotMin = time.hour * 60 + time.minute;
      final startMin = start.hour * 60 + start.minute;
      final endMin = end.hour * 60 + end.minute;
      if (startMin < endMin) {
        return slotMin >= startMin && slotMin < endMin;
      }
      return slotMin >= startMin || slotMin < endMin;
    }
    return !time.isBefore(start) && time.isBefore(end);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'presetId': presetId,
        if (recurringDaily) 'recurringDaily': recurringDaily,
      };

  factory ScheduledDnd.fromJson(Map<String, dynamic> json) {
    return ScheduledDnd(
      id: json['id'] as String,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      presetId: json['presetId'] as String,
      recurringDaily: json['recurringDaily'] as bool? ?? false,
    );
  }
}
