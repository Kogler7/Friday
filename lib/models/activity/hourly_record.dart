import '../status/status_record_data.dart';

/// 某一小时/时段的状态记录
class HourlyRecord {
  final DateTime hourStart;
  final StatusRecordData data;

  const HourlyRecord({
    required this.hourStart,
    required this.data,
  });

  String get dateKey {
    return '${hourStart.year}-${hourStart.month.toString().padLeft(2, '0')}-${hourStart.day.toString().padLeft(2, '0')}';
  }

  int get hourOfDay => hourStart.hour;

  String displayTimeRange({int unitMinutes = 20}) {
    final h = hourStart.hour;
    final m = hourStart.minute;
    String pad(int n) => n < 10 ? '0$n' : '$n';
    if (m != 0 && m != 20 && m != 40) {
      final endM = (m + 2) % 60;
      final endH = (h + (m + 2) ~/ 60) % 24;
      return '${pad(h)}:${pad(m)} - ${pad(endH)}:${pad(endM)}';
    }
    final totalMin = h * 60 + m + unitMinutes;
    final endH = (totalMin ~/ 60) % 24;
    final endM = totalMin % 60;
    return '${pad(h)}:${pad(m)} - ${pad(endH)}:${pad(endM)}';
  }

  /// 主要标签（用于图表聚合），取第一个标签或摘要
  String get primaryTag =>
      data.tagIds.isNotEmpty ? data.tagIds.first : data.summary;

  Map<String, dynamic> toJson() => {
        'hourStart': hourStart.toIso8601String(),
        'data': data.toJson(),
      };

  factory HourlyRecord.fromJson(Map<String, dynamic> json) {
    final hourStart = DateTime.parse(json['hourStart'] as String);
    final dataJson = json['data'] as Map<String, dynamic>?;
    final data = dataJson != null
        ? StatusRecordData.fromJson(dataJson)
        : const StatusRecordData();
    return HourlyRecord(hourStart: hourStart, data: data);
  }
}
