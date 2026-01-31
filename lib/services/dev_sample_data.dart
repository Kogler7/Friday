import 'package:flutter/foundation.dart';

import '../models/activity/activity_state.dart';
import '../models/activity/hourly_record.dart';
import 'storage_service.dart';

/// 开发阶段示例数据：仅 [kDebugMode] 下可用。
class DevSampleData {
  DevSampleData._();

  /// 为今天和昨天插入示例记录，用于图表与列表展示测试。
  static Future<void> insertSampleData() async {
    if (!kDebugMode) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final states = [
      ActivityState.working,
      ActivityState.resting,
      ActivityState.entertainment,
    ];

    for (final date in [yesterday, today]) {
      final isToday = date == today;
      final hours = isToday
          ? [8, 9, 10, 11, 12, 14, 15, 16, 17, 18]
          : [9, 10, 12, 14, 16];
      for (var i = 0; i < hours.length; i++) {
        final hourStart = DateTime(date.year, date.month, date.day, hours[i], 0, 0, 0);
        final state = states[i % states.length];
        await StorageService.saveRecord(HourlyRecord(hourStart: hourStart, state: state));
      }
    }
  }

  /// 清除今天和昨天的记录（仅开发用，便于重新填充示例）。
  static Future<void> clearSampleDataForTodayAndYesterday() async {
    if (!kDebugMode) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    await StorageService.clearRecordsForDate(today);
    await StorageService.clearRecordsForDate(yesterday);
  }
}
