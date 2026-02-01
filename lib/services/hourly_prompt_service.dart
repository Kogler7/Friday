import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/status/status_record_data.dart';
import 'notification_service.dart';
import 'scheduled_dnd_storage.dart';
import 'settings_service.dart';
import 'status_preset_storage.dart';
import 'storage_service.dart';

/// 按设置间隔检查：若上一间隔尚未记录则弹窗或静默时段内自动填休息。
/// 开发模式下改为每 2 分钟触发一次，便于测试。
class HourlyPromptService {
  HourlyPromptService._();

  static Timer? _timer;
  static void Function(DateTime hourToRecord)? _onShowPrompt;
  static bool _dialogShowing = false;
  /// 开发模式：已触发过的 2 分钟槽，避免同一槽重复弹窗
  static DateTime? _lastShownSlot;

  /// 设置弹窗回调（由具备 BuildContext 的页面设置）
  static void setShowPrompt(void Function(DateTime hourToRecord) callback) {
    _onShowPrompt = callback;
  }

  /// 由弹窗在关闭时调用，避免重复弹窗
  static void markDialogClosed() {
    _dialogShowing = false;
  }

  /// 由弹窗在显示时调用
  static void markDialogShowing() {
    _dialogShowing = true;
  }

  /// 启动定时检查（正式：每分钟；开发：每 15 秒，每 2 分钟弹一次）
  static void start() {
    _timer?.cancel();
    if (kDebugMode) {
      _runDevCheck();
      _timer = Timer.periodic(const Duration(seconds: 15), (_) => _runDevCheck());
    } else {
      _runProdCheck();
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _runProdCheck());
    }
  }

  /// 正式：整点后前 10 分钟内检查上一间隔；静默时段内不提醒并自动填默认状态
  static void _runProdCheck() {
    final now = DateTime.now();
    final intervalMin = SettingsService.isInitialized
        ? SettingsService.current.reminderIntervalMinutes
        : 60;
    final currentHourStart = DateTime(now.year, now.month, now.day, now.hour, 0, 0, 0);
    // 仅在前 10 分钟内检查上一间隔
    if (now.minute >= 10) return;
    final intervalStartToRecord =
        currentHourStart.subtract(Duration(minutes: intervalMin));
    final length = Duration(minutes: intervalMin);
    if (StorageService.hasRecordForInterval(intervalStartToRecord, length)) return;
    if (_dialogShowing) return;
    final dnd = ScheduledDndStorage.getActiveFor(intervalStartToRecord);
    if (dnd != null) {
      final preset = StatusPresetStorage.getById(dnd.presetId);
      final data = preset?.data ?? const StatusRecordData(tagIds: ['睡眠']);
      StorageService.saveRecordsForInterval(
        intervalStartToRecord,
        length,
        data,
      );
      return;
    }
    if (SettingsService.isInitialized &&
        SettingsService.current.isSlotInQuietPeriod(intervalStartToRecord)) {
      final presetId = SettingsService.current.quietPeriodDefaultPresetId ?? 'builtin_resting';
      final preset = StatusPresetStorage.getById(presetId);
      final data = preset?.data ?? const StatusRecordData(tagIds: ['休息']);
      StorageService.saveRecordsForInterval(
        intervalStartToRecord,
        length,
        data,
      );
      return;
    }
    NotificationService.showHourlyPrompt(intervalStartToRecord);
    _onShowPrompt?.call(intervalStartToRecord);
  }

  /// 开发：每 2 分钟一个槽，当前时间所在 2 分钟块的前一块为「待记录槽」
  static void _runDevCheck() {
    final now = DateTime.now();
    final floor2Min = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute - (now.minute % 2),
      0,
      0,
    );
    final slotToRecord = floor2Min.subtract(const Duration(minutes: 2));
    if (StorageService.getRecordForHour(slotToRecord) != null) return;
    if (_dialogShowing) return;
    if (_lastShownSlot != null && _lastShownSlot == slotToRecord) return;
    final dnd = ScheduledDndStorage.getActiveFor(slotToRecord);
    if (dnd != null) {
      final preset = StatusPresetStorage.getById(dnd.presetId);
      final data = preset?.data ?? const StatusRecordData(tagIds: ['睡眠']);
      StorageService.saveRecordsForInterval(
        slotToRecord,
        const Duration(minutes: 2),
        data,
      );
      return;
    }
    if (SettingsService.isInitialized &&
        SettingsService.current.isSlotInQuietPeriod(slotToRecord)) {
      final presetId = SettingsService.current.quietPeriodDefaultPresetId ?? 'builtin_resting';
      final preset = StatusPresetStorage.getById(presetId);
      final data = preset?.data ?? const StatusRecordData(tagIds: ['休息']);
      StorageService.saveRecordsForInterval(
        slotToRecord,
        const Duration(minutes: 2),
        data,
      );
      return;
    }
    _lastShownSlot = slotToRecord;
    NotificationService.showHourlyPrompt(slotToRecord);
    _onShowPrompt?.call(slotToRecord);
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _lastShownSlot = null;
  }
}
