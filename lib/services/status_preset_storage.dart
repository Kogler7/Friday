import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/status/status_enums.dart';
import '../models/status/status_preset.dart';
import '../models/status/status_record_data.dart';
import 'status_data_source.dart';

String get _keyPresets => StatusDataSource.key('status_presets');
String get _keyDefaultPresetId => StatusDataSource.key('status_default_preset_id');
String get _keyHiddenPresetIds => StatusDataSource.key('status_preset_hidden');

/// 预设的默认选项（工作、休息、娱乐等），首次使用时创建
List<StatusPreset> get _builtInPresets => [
      StatusPreset(
        id: 'builtin_working',
        name: '工作',
        iconCodePoint: Icons.work.codePoint,
        colorValue: 0xFF2196F3,
        data: StatusRecordData(
          energyUsage: EnergyUsage.consumption,
          physicalUsage: PhysicalUsage.normal,
          activityMotivation: ActivityMotivation.external,
          outputQuality: OutputQuality.investment,
          emotionalState: EmotionalState.average,
          energyState: EnergyState.average,
          physicalState: PhysicalState.normal,
          attentionState: AttentionState.focused,
          tagIds: ['工作'],
        ),
      ),
      StatusPreset(
        id: 'builtin_resting',
        name: '休息',
        iconCodePoint: Icons.bedtime.codePoint,
        colorValue: 0xFFFF9800,
        data: StatusRecordData(
          energyUsage: EnergyUsage.recovery,
          physicalUsage: PhysicalUsage.recovery,
          activityMotivation: ActivityMotivation.internal,
          outputQuality: OutputQuality.neutral,
          emotionalState: EmotionalState.calm,
          energyState: EnergyState.average,
          physicalState: PhysicalState.normal,
          attentionState: AttentionState.distracted,
          tagIds: ['休息'],
        ),
      ),
      StatusPreset(
        id: 'builtin_entertainment',
        name: '娱乐',
        iconCodePoint: Icons.games.codePoint,
        colorValue: 0xFF4CAF50,
        data: StatusRecordData(
          energyUsage: EnergyUsage.normal,
          physicalUsage: PhysicalUsage.normal,
          activityMotivation: ActivityMotivation.internal,
          outputQuality: OutputQuality.neutral,
          emotionalState: EmotionalState.excited,
          energyState: EnergyState.good,
          physicalState: PhysicalState.normal,
          attentionState: AttentionState.average,
          tagIds: ['娱乐'],
        ),
      ),
      StatusPreset(
        id: 'builtin_sleeping',
        name: '睡眠',
        iconCodePoint: Icons.bed.codePoint,
        colorValue: 0xFF5C6BC0,
        data: StatusRecordData(
          energyUsage: EnergyUsage.recovery,
          physicalUsage: PhysicalUsage.recovery,
          activityMotivation: ActivityMotivation.objective,
          outputQuality: OutputQuality.neutral,
          emotionalState: EmotionalState.calm,
          energyState: EnergyState.exhausted,
          physicalState: PhysicalState.low,
          attentionState: AttentionState.distracted,
          tagIds: ['睡眠'],
        ),
      ),
      StatusPreset(
        id: 'builtin_learning',
        name: '学习',
        iconCodePoint: Icons.school.codePoint,
        colorValue: 0xFF009688,
        data: StatusRecordData(
          energyUsage: EnergyUsage.consumption,
          physicalUsage: PhysicalUsage.normal,
          activityMotivation: ActivityMotivation.internal,
          outputQuality: OutputQuality.investment,
          emotionalState: EmotionalState.calm,
          energyState: EnergyState.average,
          physicalState: PhysicalState.normal,
          attentionState: AttentionState.focused,
          tagIds: ['学习'],
        ),
      ),
      StatusPreset(
        id: 'builtin_coding',
        name: '编程',
        iconCodePoint: Icons.code.codePoint,
        colorValue: 0xFF9C27B0,
        data: StatusRecordData(
          energyUsage: EnergyUsage.consumption,
          physicalUsage: PhysicalUsage.normal,
          activityMotivation: ActivityMotivation.external,
          outputQuality: OutputQuality.investment,
          emotionalState: EmotionalState.calm,
          energyState: EnergyState.average,
          physicalState: PhysicalState.normal,
          attentionState: AttentionState.flow,
          tagIds: ['编程'],
        ),
      ),
      StatusPreset(
        id: 'builtin_exercise',
        name: '运动',
        iconCodePoint: Icons.fitness_center.codePoint,
        colorValue: 0xFF4CAF50,
        data: StatusRecordData(
          energyUsage: EnergyUsage.consumption,
          physicalUsage: PhysicalUsage.consumption,
          activityMotivation: ActivityMotivation.internal,
          outputQuality: OutputQuality.accumulation,
          emotionalState: EmotionalState.excited,
          energyState: EnergyState.good,
          physicalState: PhysicalState.good,
          attentionState: AttentionState.focused,
          tagIds: ['运动'],
        ),
      ),
      StatusPreset(
        id: 'builtin_commute',
        name: '通勤',
        iconCodePoint: Icons.directions_car.codePoint,
        colorValue: 0xFF607D8B,
        data: StatusRecordData(
          energyUsage: EnergyUsage.normal,
          physicalUsage: PhysicalUsage.normal,
          activityMotivation: ActivityMotivation.objective,
          outputQuality: OutputQuality.neutral,
          emotionalState: EmotionalState.average,
          energyState: EnergyState.average,
          physicalState: PhysicalState.normal,
          attentionState: AttentionState.distracted,
          tagIds: ['通勤'],
        ),
      ),
      StatusPreset(
        id: 'builtin_meal',
        name: '就餐',
        iconCodePoint: Icons.restaurant.codePoint,
        colorValue: 0xFFE91E63,
        data: StatusRecordData(
          energyUsage: EnergyUsage.recovery,
          physicalUsage: PhysicalUsage.recovery,
          activityMotivation: ActivityMotivation.objective,
          outputQuality: OutputQuality.neutral,
          emotionalState: EmotionalState.calm,
          energyState: EnergyState.average,
          physicalState: PhysicalState.normal,
          attentionState: AttentionState.distracted,
          tagIds: ['就餐'],
        ),
      ),
      StatusPreset(
        id: 'builtin_thinking',
        name: '思考',
        iconCodePoint: Icons.psychology.codePoint,
        colorValue: 0xFF00BCD4,
        data: StatusRecordData(
          energyUsage: EnergyUsage.consumption,
          physicalUsage: PhysicalUsage.normal,
          activityMotivation: ActivityMotivation.internal,
          outputQuality: OutputQuality.accumulation,
          emotionalState: EmotionalState.calm,
          energyState: EnergyState.average,
          physicalState: PhysicalState.normal,
          attentionState: AttentionState.focused,
          tagIds: ['思考'],
        ),
      ),
      StatusPreset(
        id: 'builtin_social',
        name: '社交',
        iconCodePoint: Icons.group.codePoint,
        colorValue: 0xFF8BC34A,
        data: StatusRecordData(
          energyUsage: EnergyUsage.consumption,
          physicalUsage: PhysicalUsage.normal,
          activityMotivation: ActivityMotivation.internal,
          outputQuality: OutputQuality.neutral,
          emotionalState: EmotionalState.excited,
          energyState: EnergyState.good,
          physicalState: PhysicalState.normal,
          attentionState: AttentionState.average,
          tagIds: ['社交'],
        ),
      ),
      StatusPreset(
        id: 'builtin_housework',
        name: '家务',
        iconCodePoint: Icons.home_repair_service.codePoint,
        colorValue: 0xFF795548,
        data: StatusRecordData(
          energyUsage: EnergyUsage.consumption,
          physicalUsage: PhysicalUsage.consumption,
          activityMotivation: ActivityMotivation.internal,
          outputQuality: OutputQuality.neutral,
          emotionalState: EmotionalState.average,
          energyState: EnergyState.average,
          physicalState: PhysicalState.normal,
          attentionState: AttentionState.average,
          tagIds: ['家务'],
        ),
      ),
    ];

/// 预设存储
class StatusPresetStorage {
  StatusPresetStorage._();
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await ensureBuiltInPresets();
  }

  static Future<void> ensureBuiltInPresets() async {
    final list = getAll(includeHidden: true);
    final ids = list.map((p) => p.id).toSet();
    for (final p in _builtInPresets) {
      if (!ids.contains(p.id)) {
        await save(p);
      }
    }
  }

  static Set<String> _getHiddenIds() {
    final jsonStr = _prefs.getString(_keyHiddenPresetIds);
    if (jsonStr == null) return {};
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> _setHiddenIds(Set<String> ids) async {
    await _prefs.setString(_keyHiddenPresetIds, jsonEncode(ids.toList()));
  }

  static Future<void> setHidden(String id, bool hidden) async {
    final ids = _getHiddenIds();
    if (hidden) ids.add(id);
    else ids.remove(id);
    await _setHiddenIds(ids);
  }

  static Future<void> restoreBuiltInVisibility() async {
    final ids = _getHiddenIds();
    for (final p in _builtInPresets) {
      ids.remove(p.id);
    }
    await _setHiddenIds(ids);
  }

  /// 获取所有预设
  static List<StatusPreset> getAll({bool includeHidden = false}) {
    final jsonStr = _prefs.getString(_keyPresets);
    List<StatusPreset> list = [];
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        list = decoded
            .map((e) => StatusPreset.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    final hiddenIds = _getHiddenIds();
    final merged = list.map((p) => p.copyWith(hidden: hiddenIds.contains(p.id))).toList();
    if (!includeHidden) return merged.where((p) => !p.hidden).toList();
    return merged;
  }

  static StatusPreset? getById(String id) {
    try {
      return getAll(includeHidden: true).firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(StatusPreset preset) async {
    final list = getAll(includeHidden: true);
    final idx = list.indexWhere((p) => p.id == preset.id);
    if (idx >= 0) {
      list[idx] = preset;
    } else {
      list.add(preset);
    }
    await _prefs.setString(
      _keyPresets,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> delete(String id) async {
    final list = getAll(includeHidden: true).where((p) => p.id != id).toList();
    await _prefs.setString(
      _keyPresets,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
    final hiddenIds = _getHiddenIds();
    hiddenIds.remove(id);
    await _setHiddenIds(hiddenIds);
    if (getDefaultPresetId() == id) {
      await setDefaultPresetId(null);
    }
  }

  static String? getDefaultPresetId() =>
      _prefs.getString(_keyDefaultPresetId);

  static Future<void> setDefaultPresetId(String? id) async {
    if (id == null) {
      await _prefs.remove(_keyDefaultPresetId);
    } else {
      await _prefs.setString(_keyDefaultPresetId, id);
    }
  }
}
