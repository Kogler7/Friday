import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notification_service.dart';
import 'storage_service.dart';

/// 每小时整点检查：若上一小时尚未记录，则通过 [onShowPrompt] 请求弹窗。
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

  /// 正式：整点后前 10 分钟内检查上一小时
  static void _runProdCheck() {
    final now = DateTime.now();
    final currentHourStart = DateTime(now.year, now.month, now.day, now.hour);
    if (now.minute >= 10) return;
    final hourToRecord = currentHourStart.subtract(const Duration(hours: 1));
    if (StorageService.getRecordForHour(hourToRecord) != null) return;
    if (_dialogShowing) return;
    NotificationService.showHourlyPrompt(hourToRecord);
    _onShowPrompt?.call(hourToRecord);
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
