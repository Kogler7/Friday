/// 预定免打扰：到点自动填充，不弹窗
class ScheduledDnd {
  final String id;
  final DateTime start;
  final DateTime end;
  final String presetId;

  const ScheduledDnd({
    required this.id,
    required this.start,
    required this.end,
    required this.presetId,
  });

  /// 某时刻是否在此免打扰范围内
  bool contains(DateTime time) {
    return !time.isBefore(start) && time.isBefore(end);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'presetId': presetId,
      };

  factory ScheduledDnd.fromJson(Map<String, dynamic> json) {
    return ScheduledDnd(
      id: json['id'] as String,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      presetId: json['presetId'] as String,
    );
  }
}
