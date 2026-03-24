import 'package:flutter/foundation.dart';

import '../../domain/repositories/status_repository.dart';
import '../../models/activity/hourly_record.dart';
import '../../models/status/status_record_data.dart';
import 'in_memory_cache.dart';

class RemoteStatusRepository implements StatusRepository {
  RemoteStatusRepository(this._cache);

  final InMemoryCache _cache;

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
    return DateTime(
      slotStart.year,
      slotStart.month,
      slotStart.day,
      slotStart.hour,
      slotStart.minute,
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  List<HourlyRecord> getRecordsForDate(DateTime date) {
    return List<HourlyRecord>.from(
      _cache.statusByDate[_dateKey(date)] ?? const [],
    );
  }

  @override
  HourlyRecord? getRecordForHour(DateTime slotStart) {
    final normalized = _normalizeSlot(slotStart);
    final list = getRecordsForDate(normalized);
    try {
      return list.firstWhere((e) => e.hourStart == normalized);
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
    final key = _dateKey(normalized.hourStart);
    final list = List<HourlyRecord>.from(_cache.statusByDate[key] ?? const []);
    list.removeWhere((e) => e.hourStart == normalized.hourStart);
    list.add(normalized);
    list.sort((a, b) => a.hourStart.compareTo(b.hourStart));
    _cache.statusByDate[key] = list;
  }

  @override
  Future<void> clearRecordsForDate(DateTime date) async {
    _cache.statusByDate.remove(_dateKey(date));
  }

  @override
  Future<void> clearRecordsInRange(DateTime start, DateTime end) async {
    var date = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!date.isAfter(endDate)) {
      _cache.statusByDate.remove(_dateKey(date));
      date = date.add(const Duration(days: 1));
    }
  }

  @override
  Future<void> clearAllRecords() async {
    _cache.statusByDate.clear();
  }

  @override
  bool hasRecordForInterval(DateTime intervalStart, Duration length) {
    final unit = kDebugMode ? 2 : 20;
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
    final unit = kDebugMode ? 2 : 20;
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
      for (final record in getRecordsForDate(date)) {
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
    final result = <HourlyRecord>[];
    for (var d = 1; d <= daysBack; d++) {
      final date = normalized.subtract(Duration(days: d));
      final target = DateTime(
        date.year,
        date.month,
        date.day,
        normalized.hour,
        normalized.minute,
      );
      final record = getRecordForHour(target);
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
    final unit = kDebugMode ? 2 : 20;
    var date = DateTime(dateStart.year, dateStart.month, dateStart.day);
    final endDate = DateTime(dateEnd.year, dateEnd.month, dateEnd.day);
    while (!date.isAfter(endDate)) {
      var curMin = startHour * 60 + startMinute;
      final rawEnd = endHour * 60 + endMinute;
      final endMin = rawEnd <= curMin ? rawEnd + 24 * 60 : rawEnd;
      while (curMin < endMin) {
        final h = (curMin ~/ 60) % 24;
        final m = curMin % 60;
        await saveRecord(
          HourlyRecord(
            hourStart: DateTime(date.year, date.month, date.day, h, m),
            data: data,
          ),
        );
        curMin += unit;
      }
      date = date.add(const Duration(days: 1));
    }
  }
}
