import 'package:flutter/foundation.dart';

import '../data/repositories/repository_facade.dart';
import '../models/activity/hourly_record.dart';
import '../models/status/status_record_data.dart';

/// 开发阶段示例数据：仅 [kDebugMode] 下可用。
class DevSampleData {
  DevSampleData._();

  static const List<StatusRecordData> _sampleData = [
    StatusRecordData(tagIds: ['工作']),
    StatusRecordData(tagIds: ['休息']),
    StatusRecordData(tagIds: ['娱乐']),
  ];

  /// 为今天和昨天插入示例记录，用于图表与列表展示测试。
  static Future<void> insertSampleData() async {
    if (!kDebugMode) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final date in [yesterday, today]) {
      final isToday = date == today;
      final hours = isToday
          ? [8, 9, 10, 11, 12, 14, 15, 16, 17, 18]
          : [9, 10, 12, 14, 16];
      for (var i = 0; i < hours.length; i++) {
        final hourStart = DateTime(
          date.year,
          date.month,
          date.day,
          hours[i],
          0,
          0,
          0,
        );
        final data = _sampleData[i % _sampleData.length];
        await RepositoryFacade.status.saveRecord(
          HourlyRecord(hourStart: hourStart, data: data),
        );
      }
    }
  }

  /// 清除今天和昨天的记录（仅开发用，便于重新填充示例）。
  static Future<void> clearSampleDataForTodayAndYesterday() async {
    if (!kDebugMode) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    await RepositoryFacade.status.clearRecordsForDate(today);
    await RepositoryFacade.status.clearRecordsForDate(yesterday);
  }
}
