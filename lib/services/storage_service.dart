import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hourly_record.dart';

const String _keyPrefix = 'planplus_hourly_';

/// 按日期存储小时记录，key 为 dateKey（如 2025-01-30），value 为 HourlyRecord 列表的 JSON
class StorageService {
  StorageService._();
  static late final SharedPreferences _prefs;

  /// 开发模式下按 2 分钟粒度；正式模式按整点
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
    return DateTime(
      slotStart.year,
      slotStart.month,
      slotStart.day,
      slotStart.hour,
      0,
      0,
      0,
    );
  }

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
}
