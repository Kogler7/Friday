import 'package:flutter/material.dart';

/// 状态统计与提醒相关设置（可扩展，后期支持批量修改）
class SettingsPreferences {
  /// 状态统计单位（分钟），如 20 表示每 20 分钟一个单位
  final int statUnitMinutes;

  /// 提醒间隔（分钟），默认 60 表示每小时提醒一次
  final int reminderIntervalMinutes;

  /// 静默时段开始（不提醒），如 2:00
  final TimeOfDay quietPeriodStart;

  /// 静默时段结束（不提醒），如 10:00，跨日表示次日早上
  final TimeOfDay quietPeriodEnd;

  /// 静默时段内未记录时默认预设 ID（对应 StatusPreset.id）
  final String? quietPeriodDefaultPresetId;

  /// 主题模式：跟随系统 / 浅色 / 深色
  final ThemeMode themeMode;

  /// 主题色（Color.value），用于 ColorScheme.fromSeed
  final int seedColorValue;

  const SettingsPreferences({
    this.statUnitMinutes = 20,
    this.reminderIntervalMinutes = 60,
    this.quietPeriodStart = const TimeOfDay(hour: 2, minute: 0),
    this.quietPeriodEnd = const TimeOfDay(hour: 10, minute: 0),
    this.quietPeriodDefaultPresetId,
    this.themeMode = ThemeMode.system,
    this.seedColorValue = 0xFF673AB7,
  });

  /// 某时刻是否处于静默时段（2:00～10:00 视为静默，不含 10:00）
  bool isInQuietPeriod(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final minutesSinceMidnight = hour * 60 + minute;
    final startMinutes =
        quietPeriodStart.hour * 60 + quietPeriodStart.minute;
    int endMinutes = quietPeriodEnd.hour * 60 + quietPeriodEnd.minute;
    if (endMinutes <= startMinutes) {
      endMinutes += 24 * 60; // 跨日
    }
    if (minutesSinceMidnight >= startMinutes && minutesSinceMidnight < endMinutes) {
      return true;
    }
    if (endMinutes > 24 * 60 && minutesSinceMidnight < (endMinutes - 24 * 60)) {
      return true;
    }
    return false;
  }

  /// 某时段起点（如整点）是否在静默时段内
  bool isSlotInQuietPeriod(DateTime slotStart) {
    return isInQuietPeriod(slotStart);
  }

  SettingsPreferences copyWith({
    int? statUnitMinutes,
    int? reminderIntervalMinutes,
    TimeOfDay? quietPeriodStart,
    TimeOfDay? quietPeriodEnd,
    String? quietPeriodDefaultPresetId,
    ThemeMode? themeMode,
    int? seedColorValue,
  }) {
    return SettingsPreferences(
      statUnitMinutes: statUnitMinutes ?? this.statUnitMinutes,
      reminderIntervalMinutes:
          reminderIntervalMinutes ?? this.reminderIntervalMinutes,
      quietPeriodStart: quietPeriodStart ?? this.quietPeriodStart,
      quietPeriodEnd: quietPeriodEnd ?? this.quietPeriodEnd,
      quietPeriodDefaultPresetId:
          quietPeriodDefaultPresetId ?? this.quietPeriodDefaultPresetId,
      themeMode: themeMode ?? this.themeMode,
      seedColorValue: seedColorValue ?? this.seedColorValue,
    );
  }
}
