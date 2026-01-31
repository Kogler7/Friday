import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity/activity_state.dart';
import '../models/activity/hourly_record.dart';
import 'settings_service.dart';

const String _keyPrefix = 'planplus_hourly_';

/// 按日期存储时段记录，槽位按设置中的统计单位（默认 20 分钟）归一化
class StorageService {
  StorageService._();
  static late final SharedPreferences _prefs;

  /// 开发模式下按 2 分钟粒度；正式模式按设置中的统计单位（默认 20 分钟）
  static DateTime _normalizeSlot(DateTime slotStart) {
    if (kDebugMode) {
      final m = slotStart.minute - (slotStart.minute % 2);
      return DateTime(
        slotStart.year,
        slotStart.month,
        slotStart.day,
        slotStart.hour,
        m,
        0,
        0,
      );
    }
    final unit = SettingsService.isInitialized
        ? SettingsService.current.statUnitMinutes
        : 20;
    final totalMinutes =
        slotStart.hour * 60 + slotStart.minute + slotStart.second ~/ 60;
    final rounded = (totalMinutes ~/ unit) * unit;
    final h = rounded ~/ 60;
    final m = rounded % 60;
    return DateTime(
      slotStart.year,
      slotStart.month,
      slotStart.day,
      h % 24,
      m,
      0,
      0,
    );
  }

  /// 统计单位（分钟），用于生成间隔内槽位
  static int get _statUnitMinutes =>
      SettingsService.isInitialized
          ? SettingsService.current.statUnitMinutes
          : 20;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String _recordKey(String dateKey) => '$_keyPrefix$dateKey';

  /// 获取某天的所有小时记录
  static List<HourlyRecord> getRecordsForDate(DateTime date) {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final jsonStr = _prefs.getString(_recordKey(dateKey));
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => HourlyRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取某小时/某时段是否已有记录（正式：整点如 14:00；开发：2 分钟槽如 14:30）
  static HourlyRecord? getRecordForHour(DateTime slotStart) {
    final normalized = _normalizeSlot(slotStart);
    final records = getRecordsForDate(normalized);
    try {
      return records.firstWhere((r) => r.hourStart == normalized);
    } catch (_) {
      return null;
    }
  }

  /// 保存或更新一条小时记录
  static Future<void> saveRecord(HourlyRecord record) async {
    final normalized = HourlyRecord(
      hourStart: _normalizeSlot(record.hourStart),
      state: record.state,
    );
    final dateKey = normalized.dateKey;
    final records = getRecordsForDate(normalized.hourStart);
    final filtered =
        records.where((r) => r.hourStart != normalized.hourStart).toList();
    filtered.add(normalized);
    filtered.sort((a, b) => a.hourStart.compareTo(b.hourStart));
    final jsonStr = jsonEncode(filtered.map((e) => e.toJson()).toList());
    await _prefs.setString(_recordKey(dateKey), jsonStr);
  }

  /// 清除某天的所有记录（用于开发时重置示例数据）
  static Future<void> clearRecordsForDate(DateTime date) async {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _prefs.remove(_recordKey(dateKey));
  }

  /// 判断某间隔内是否已有完整记录（每个统计单位槽位都有）
  static bool hasRecordForInterval(DateTime intervalStart, Duration length) {
    final unit = kDebugMode ? 2 : _statUnitMinutes;
    final totalSlots = length.inMinutes ~/ unit;
    for (var i = 0; i < totalSlots; i++) {
      final slot = intervalStart.add(Duration(minutes: i * unit));
      if (getRecordForHour(slot) == null) return false;
    }
    return true;
  }

  /// 将某间隔内所有统计单位槽位保存为同一状态（用于提醒选择后或静默时段自动填充）
  static Future<void> saveRecordsForInterval(
    DateTime intervalStart,
    Duration length,
    ActivityState state,
  ) async {
    final unit = kDebugMode ? 2 : _statUnitMinutes;
    final totalSlots = length.inMinutes ~/ unit;
    for (var i = 0; i < totalSlots; i++) {
      final slotStart = intervalStart.add(Duration(minutes: i * unit));
      await saveRecord(HourlyRecord(hourStart: slotStart, state: state));
    }
  }
}
