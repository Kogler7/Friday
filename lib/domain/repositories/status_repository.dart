import '../../models/activity/hourly_record.dart';
import '../../models/status/status_record_data.dart';

abstract class StatusRepository {
  List<HourlyRecord> getRecordsForDate(DateTime date);

  HourlyRecord? getRecordForHour(DateTime slotStart);

  Future<void> saveRecord(HourlyRecord record);

  Future<void> clearRecordsForDate(DateTime date);

  Future<void> clearRecordsInRange(DateTime start, DateTime end);

  Future<void> clearAllRecords();

  bool hasRecordForInterval(DateTime intervalStart, Duration length);

  Future<void> saveRecordsForInterval(
    DateTime intervalStart,
    Duration length,
    StatusRecordData data,
  );

  List<HourlyRecord> getRecordsInRange(DateTime start, DateTime end);

  List<HourlyRecord> getRecordsForSlotAcrossDays(
    DateTime slotStart,
    int daysBack,
  );

  Future<void> saveRecordsForBatch({
    required DateTime dateStart,
    required DateTime dateEnd,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required StatusRecordData data,
  });
}
