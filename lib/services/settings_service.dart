import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_state.dart';
import '../models/settings_preferences.dart';

const String _keySettings = 'planplus_settings';

/// 设置持久化与全局访问；应用启动时需先 [init]。
class SettingsService {
  SettingsService._();

  static late SharedPreferences _prefs;
  static SettingsPreferences _current = const SettingsPreferences();

  static SettingsPreferences get current => _current;

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _load();
    _initialized = true;
  }

  static Future<void> _load() async {
    final jsonStr = _prefs.getString(_keySettings);
    if (jsonStr == null) return;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      _current = _fromJson(map);
    } catch (_) {}
  }

  static Future<void> save(SettingsPreferences prefs) async {
    _current = prefs;
    final map = _toJson(prefs);
    await _prefs.setString(_keySettings, jsonEncode(map));
  }

  static Map<String, dynamic> _toJson(SettingsPreferences p) {
    return {
      'statUnitMinutes': p.statUnitMinutes,
      'reminderIntervalMinutes': p.reminderIntervalMinutes,
      'quietStartHour': p.quietPeriodStart.hour,
      'quietStartMinute': p.quietPeriodStart.minute,
      'quietEndHour': p.quietPeriodEnd.hour,
      'quietEndMinute': p.quietPeriodEnd.minute,
      'quietDefaultState': p.quietPeriodDefaultState.value,
    };
  }

  static SettingsPreferences _fromJson(Map<String, dynamic> map) {
    return SettingsPreferences(
      statUnitMinutes: (map['statUnitMinutes'] as num?)?.toInt() ?? 20,
      reminderIntervalMinutes:
          (map['reminderIntervalMinutes'] as num?)?.toInt() ?? 60,
      quietPeriodStart: TimeOfDay(
        hour: (map['quietStartHour'] as num?)?.toInt() ?? 2,
        minute: (map['quietStartMinute'] as num?)?.toInt() ?? 0,
      ),
      quietPeriodEnd: TimeOfDay(
        hour: (map['quietEndHour'] as num?)?.toInt() ?? 10,
        minute: (map['quietEndMinute'] as num?)?.toInt() ?? 0,
      ),
      quietPeriodDefaultState: ActivityStateExtension.fromValue(
        map['quietDefaultState'] as String? ?? 'resting',
      ),
    );
  }
}
