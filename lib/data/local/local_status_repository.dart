import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/status_repository.dart';
import '../../models/activity/hourly_record.dart';
import '../../models/status/status_record_data.dart';
import '../../services/settings_service.dart';
import '../../services/status_data_source.dart';

class LocalStatusRepository implements StatusRepository {
  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  DateTime _normalizeSlot(DateTime slotStart) {
    if (kDebugMode) {
      final m = slotStart.minute - (slotStart.minute % 2);
      return DateTime(
        slotStart.year,
        slotStart.month,
        slotStart.day,
        slotStart.hour,
        m,
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
    return DateTime(slotStart.year, slotStart.month, slotStart.day, h % 24, m);
  }

  int get _statUnitMinutes => SettingsService.isInitialized
      ? SettingsService.current.statUnitMinutes
      : 20;

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _recordKey(String dateKey) =>
      StatusDataSource.key('v2_hourly_$dateKey');

  String _legacyRecordKey(String dateKey) =>
      StatusDataSource.key('hourly_$dateKey');

  List<HourlyRecord> _loadV2ForDate(DateTime date) {
    final jsonStr = _prefs.getString(_recordKey(_dateKey(date)));
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => HourlyRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<HourlyRecord> _loadLegacyForDate(DateTime date) {
    final jsonStr = _prefs.getString(_legacyRecordKey(_dateKey(date)));
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => HourlyRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveV2ForDate(DateTime date, List<HourlyRecord> records) async {
    final jsonStr = jsonEncode(records.map((e) => e.toJson()).toList());
    await _prefs.setString(_recordKey(_dateKey(date)), jsonStr);
  }

  bool _hasV2ForDate(DateTime date) =>
      _prefs.containsKey(_recordKey(_dateKey(date)));

  Map<String, List<HourlyRecord>> exportAllByDate() {
    final result = <String, List<HourlyRecord>>{};
    final v2Prefix = StatusDataSource.key('v2_hourly_');
    final legacyPrefix = StatusDataSource.key('hourly_');
    final keys = _prefs.getKeys().where(
      (k) => k.startsWith(v2Prefix) || k.startsWith(legacyPrefix),
    );
    for (final key in keys) {
      final isV2 = key.startsWith(v2Prefix);
      final dateKey = key.substring(
        isV2 ? v2Prefix.length : legacyPrefix.length,
      );
      if (!isV2 && result.containsKey(dateKey)) continue;
      final list = _loadV2ForDate(DateTime.parse('${dateKey}T00:00:00'));
      if (list.isNotEmpty || isV2) {
        result[dateKey] = list;
      } else {
        final legacyList = _loadLegacyForDate(
          DateTime.parse('${dateKey}T00:00:00'),
        );
        if (legacyList.isNotEmpty) {
          result[dateKey] = legacyList;
        }
      }
    }
    return result;
  }

  @override
  List<HourlyRecord> getRecordsForDate(DateTime date) {
    final v2 = _loadV2ForDate(date);
    if (v2.isNotEmpty || _hasV2ForDate(date)) return v2;
    return _loadLegacyForDate(date);
  }

  @override
  HourlyRecord? getRecordForHour(DateTime slotStart) {
    final normalized = _normalizeSlot(slotStart);
    final records = getRecordsForDate(normalized);
    try {
      return records.firstWhere((r) => r.hourStart == normalized);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveRecord(HourlyRecord record) async {
    final normalized = HourlyRecord(
      hourStart: _normalizeSlot(record.hourStart),
      data: record.data,
    );
    final records = getRecordsForDate(normalized.hourStart);
    final filtered =
        records.where((r) => r.hourStart != normalized.hourStart).toList()
          ..add(normalized)
          ..sort((a, b) => a.hourStart.compareTo(b.hourStart));
    await _saveV2ForDate(normalized.hourStart, filtered);
  }

  @override
  Future<void> clearRecordsForDate(DateTime date) async {
    await _prefs.remove(_recordKey(_dateKey(date)));
  }

  @override
  Future<void> clearRecordsInRange(DateTime start, DateTime end) async {
    var date = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!date.isAfter(endDate)) {
      await clearRecordsForDate(date);
      date = date.add(const Duration(days: 1));
    }
  }

  @override
  Future<void> clearAllRecords() async {
    final prefix = StatusDataSource.key('v2_hourly_');
    final keys = _prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  @override
  bool hasRecordForInterval(DateTime intervalStart, Duration length) {
    final unit = kDebugMode ? 2 : _statUnitMinutes;
    final totalSlots = length.inMinutes ~/ unit;
    for (var i = 0; i < totalSlots; i++) {
      final slot = intervalStart.add(Duration(minutes: i * unit));
      if (getRecordForHour(slot) == null) return false;
    }
    return true;
  }

  @override
  Future<void> saveRecordsForInterval(
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

  @override
  List<HourlyRecord> getRecordsInRange(DateTime start, DateTime end) {
    final result = <HourlyRecord>[];
    var date = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!date.isAfter(endDate)) {
      final dayRecords = getRecordsForDate(date);
      for (final record in dayRecords) {
        if (!record.hourStart.isBefore(start) &&
            !record.hourStart.isAfter(end)) {
          result.add(record);
        }
      }
      date = date.add(const Duration(days: 1));
    }
    result.sort((a, b) => a.hourStart.compareTo(b.hourStart));
    return result;
  }

  @override
  List<HourlyRecord> getRecordsForSlotAcrossDays(
    DateTime slotStart,
    int daysBack,
  ) {
    final normalized = _normalizeSlot(slotStart);
    final hour = normalized.hour;
    final minute = normalized.minute;
    final result = <HourlyRecord>[];
    for (var d = 1; d <= daysBack; d++) {
      final date = normalized.subtract(Duration(days: d));
      final slot = DateTime(date.year, date.month, date.day, hour, minute);
      final record = getRecordForHour(slot);
      if (record != null) result.add(record);
    }
    return result;
  }

  @override
  Future<void> saveRecordsForBatch({
    required DateTime dateStart,
    required DateTime dateEnd,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required StatusRecordData data,
  }) async {
    final unit = kDebugMode ? 2 : _statUnitMinutes;
    var date = DateTime(dateStart.year, dateStart.month, dateStart.day);
    final endDate = DateTime(dateEnd.year, dateEnd.month, dateEnd.day);
    while (!date.isAfter(endDate)) {
      var curMin = startHour * 60 + startMinute;
      final rawEnd = endHour * 60 + endMinute;
      final endMin = rawEnd <= curMin ? rawEnd + 24 * 60 : rawEnd;
      while (curMin < endMin) {
        final h = (curMin ~/ 60) % 24;
        final m = curMin % 60;
        final slot = DateTime(date.year, date.month, date.day, h, m);
        await saveRecord(
          HourlyRecord(hourStart: _normalizeSlot(slot), data: data),
        );
        curMin += unit;
      }
      date = date.add(const Duration(days: 1));
    }
  }
}
