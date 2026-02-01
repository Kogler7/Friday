import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/default_activity_tags.dart';
import '../models/status/activity_tag.dart';
import 'status_data_source.dart';

String get _keyTags => StatusDataSource.key('activity_tags');
String get _keyHiddenNames => StatusDataSource.key('activity_tag_hidden');
String get _keyStarredNames => StatusDataSource.key('activity_tag_starred');

/// 默认活动标签（指向内置列表）
List<ActivityTag> get defaultActivityTags => List.from(builtInActivityTags);

/// 活动标签存储（用户可添加自定义标签、设置 hidden）
class ActivityTagStorage {
  ActivityTagStorage._();
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Set<String> _getHiddenNames() {
    final jsonStr = _prefs.getString(_keyHiddenNames);
    if (jsonStr == null) return {};
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> _setHiddenNames(Set<String> names) async {
    await _prefs.setString(_keyHiddenNames, jsonEncode(names.toList()));
  }

  /// 获取所有标签（默认 + 用户自定义）
  /// [includeHidden] 为 false 时过滤掉 hidden 的标签
  static List<ActivityTag> getAll({bool includeHidden = true}) {
    final hiddenNames = _getHiddenNames();
    final jsonStr = _prefs.getString(_keyTags);
    List<ActivityTag> custom = [];
    if (jsonStr != null) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        custom = list
            .map((e) => ActivityTag.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    final defaultNames = builtInActivityTags.map((t) => t.name).toSet();
    final combined = [
      ...builtInActivityTags.map((t) => t.copyWith(hidden: hiddenNames.contains(t.name))),
      ...custom.where((t) => !defaultNames.contains(t.name)),
    ];
    if (!includeHidden) {
      return combined.where((t) => !t.hidden).toList();
    }
    return combined;
  }

  /// 获取可见标签（用于选择器）
  static List<ActivityTag> getVisible() => getAll(includeHidden: false);

  static Set<String> _getStarredNames() {
    final jsonStr = _prefs.getString(_keyStarredNames);
    if (jsonStr == null) return {};
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> _setStarredNames(Set<String> names) async {
    await _prefs.setString(_keyStarredNames, jsonEncode(names.toList()));
  }

  /// 星标标签（用于推荐/搜索排序，排在最前）
  static Set<String> getStarredNames() => _getStarredNames();

  static Future<void> setStarred(String name, bool starred) async {
    final names = _getStarredNames();
    if (starred) {
      names.add(name);
    } else {
      names.remove(name);
    }
    await _setStarredNames(names);
  }

  /// 可见标签，星标排前
  static List<ActivityTag> getVisibleSortedByStarred() {
    final tags = getVisible();
    final starred = _getStarredNames();
    tags.sort((a, b) {
      final aStarred = starred.contains(a.name);
      final bStarred = starred.contains(b.name);
      if (aStarred != bStarred) return aStarred ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return tags;
  }

  /// 根据 name 查找标签
  static ActivityTag? getByName(String name) {
    try {
      return getAll().firstWhere((t) => t.name == name);
    } catch (_) {
      return null;
    }
  }

  /// 兼容
  static ActivityTag? getById(String name) => getByName(name);

  /// 添加自定义标签
  static Future<void> addTag(ActivityTag tag) async {
    if (tag.name.trim().isEmpty) return;
    final all = getAll();
    if (all.any((t) => t.name == tag.name)) return;
    final custom = all.where((t) => !builtInActivityTags.any((d) => d.name == t.name)).toList();
    custom.add(tag);
    await _saveCustom(custom);
  }

  /// 删除标签（仅自定义标签可删）
  static Future<void> deleteTag(String name) async {
    if (builtInActivityTags.any((d) => d.name == name)) return;
    final custom = getAll().where((t) => builtInActivityTags.every((d) => d.name != t.name)).toList();
    custom.removeWhere((t) => t.name == name);
    await _saveCustom(custom);
  }

  /// 更新标签
  static Future<void> updateTag(ActivityTag tag) async {
    final all = getAll();
    final custom = all.where((t) => !builtInActivityTags.any((d) => d.name == t.name)).toList();
    final idx = custom.indexWhere((t) => t.name == tag.name);
    if (idx >= 0) {
      custom[idx] = tag;
    } else {
      custom.add(tag);
    }
    await _saveCustom(custom);
  }

  /// 恢复默认：清除所有 hidden 覆盖，内置标签全部可见
  static Future<void> restoreDefaults() async {
    await _setHiddenNames({});
  }

  /// 设置标签 hidden 状态
  static Future<void> setHidden(String name, bool hidden) async {
    final hiddenNames = _getHiddenNames();
    if (hidden) {
      hiddenNames.add(name);
    } else {
      hiddenNames.remove(name);
    }
    await _setHiddenNames(hiddenNames);
  }

  static Future<void> _saveCustom(List<ActivityTag> custom) async {
    await _prefs.setString(
      _keyTags,
      jsonEncode(custom.map((e) => e.toJson()).toList()),
    );
  }
}
