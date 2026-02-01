import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity/hourly_record.dart';
import '../models/status/status_record_data.dart';
import 'settings_service.dart';
import 'status_data_source.dart';

String get _keyPrefix => StatusDataSource.key('hourly_');

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

  static String _recordKey(String dateKey) => _keyPrefix + dateKey;

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
      data: record.data,
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

  /// 清除某天的所有记录
  static Future<void> clearRecordsForDate(DateTime date) async {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _prefs.remove(_recordKey(dateKey));
  }

  /// 清除日期范围内的所有记录
  static Future<void> clearRecordsInRange(DateTime start, DateTime end) async {
    var date = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!date.isAfter(endDate)) {
      await clearRecordsForDate(date);
      date = date.add(const Duration(days: 1));
    }
  }

  /// 清除当前数据源下所有记录
  static Future<void> clearAllRecords() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_keyPrefix)).toList();
    for (final k in keys) await _prefs.remove(k);
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

  /// 将某间隔内所有统计单位槽位保存为同一数据（用于提醒选择后或静默时段自动填充）
  static Future<void> saveRecordsForInterval(
    DateTime intervalStart,
    Duration length,
    StatusRecordData data,
  ) async {
    final unit = kDebugMode ? 2 : _statUnitMinutes;
    final totalSlots = length.inMinutes ~/ unit;
    for (var i = 0; i < totalSlots; i++) {
      final slotStart = intervalStart.add(Duration(minutes: i * unit));
      await saveRecord(HourlyRecord(hourStart: slotStart, data: data));
    }
  }

  /// 获取时间范围内的记录（用于统计）
  static List<HourlyRecord> getRecordsInRange(DateTime start, DateTime end) {
    final result = <HourlyRecord>[];
    var date = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!date.isAfter(endDate)) {
      final dayRecords = getRecordsForDate(date);
      for (final r in dayRecords) {
        if (!r.hourStart.isBefore(start) && !r.hourStart.isAfter(end)) {
          result.add(r);
        }
      }
      date = date.add(const Duration(days: 1));
    }
    result.sort((a, b) => a.hourStart.compareTo(b.hourStart));
    return result;
  }

  /// 过去 [daysBack] 天同一时刻（相同时分）的记录
  static List<HourlyRecord> getRecordsForSlotAcrossDays(
    DateTime slotStart,
    int daysBack,
  ) {
    final normalized = _normalizeSlot(slotStart);
    final hour = normalized.hour;
    final minute = normalized.minute;
    final result = <HourlyRecord>[];
    for (var d = 1; d <= daysBack; d++) {
      final date = normalized.subtract(Duration(days: d));
      final slot = DateTime(date.year, date.month, date.day, hour, minute, 0, 0);
      final r = getRecordForHour(slot);
      if (r != null) result.add(r);
    }
    return result;
  }

  /// 批量设置：将指定日期范围内的每日 [timeStart]-[timeEnd] 槽位设为 [data]
  static Future<void> saveRecordsForBatch({
    required DateTime dateStart,
    required DateTime dateEnd,
    required TimeOfDay timeStart,
    required TimeOfDay timeEnd,
    required StatusRecordData data,
  }) async {
    final unit = kDebugMode ? 2 : _statUnitMinutes;
    var date = DateTime(dateStart.year, dateStart.month, dateStart.day);
    final endDate = DateTime(dateEnd.year, dateEnd.month, dateEnd.day);
    while (!date.isAfter(endDate)) {
      var curMin = timeStart.hour * 60 + timeStart.minute;
      final endMin = timeEnd.hour * 60 + timeEnd.minute;
      final endMinAdjusted = endMin <= curMin ? endMin + 24 * 60 : endMin;
      while (curMin < endMinAdjusted) {
        final h = (curMin ~/ 60) % 24;
        final m = curMin % 60;
        final slot = DateTime(date.year, date.month, date.day, h, m, 0, 0);
        await saveRecord(HourlyRecord(hourStart: _normalizeSlot(slot), data: data));
        curMin += unit;
      }
      date = date.add(const Duration(days: 1));
    }
  }
}
