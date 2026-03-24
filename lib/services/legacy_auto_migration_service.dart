import 'package:shared_preferences/shared_preferences.dart';

import 'status_data_source.dart';

/// 旧数据自动迁移入口（默认关闭）。
/// 仅在未存在 v2 数据时复制旧 key 到 v2 key，不删除旧数据，可随时回滚。
class LegacyAutoMigrationService {
  LegacyAutoMigrationService._();

  static const bool enabledByDefault = false;

  static Future<void> runIfEnabled({bool enabled = enabledByDefault}) async {
    if (!enabled) return;
    final prefs = await SharedPreferences.getInstance();
    await _migrateTodo(prefs);
    await _migrateIdea(prefs);
    await _migrateStatus(prefs);
  }

  static Future<void> _migrateTodo(SharedPreferences prefs) async {
    const legacyKey = 'friday_todo';
    const v2Key = 'friday_v2_todo_items';
    if (prefs.containsKey(v2Key)) return;
    final raw = prefs.getString(legacyKey);
    if (raw != null && raw.isNotEmpty) {
      await prefs.setString(v2Key, raw);
    }
  }

  static Future<void> _migrateIdea(SharedPreferences prefs) async {
    const legacySessions = 'friday_idea_sessions';
    const legacyCurrentId = 'friday_idea_current_id';
    const v2Sessions = 'friday_v2_idea_sessions';
    const v2CurrentId = 'friday_v2_idea_current_id';

    if (!prefs.containsKey(v2Sessions)) {
      final raw = prefs.getString(legacySessions);
      if (raw != null && raw.isNotEmpty) {
        await prefs.setString(v2Sessions, raw);
      }
    }
    if (!prefs.containsKey(v2CurrentId)) {
      final id = prefs.getString(legacyCurrentId);
      if (id != null && id.isNotEmpty) {
        await prefs.setString(v2CurrentId, id);
      }
    }
  }

  static Future<void> _migrateStatus(SharedPreferences prefs) async {
    final legacyPrefix = StatusDataSource.key('hourly_');
    final v2Prefix = StatusDataSource.key('v2_hourly_');
    final keys = prefs.getKeys().where((k) => k.startsWith(legacyPrefix));
    for (final key in keys) {
      final suffix = key.substring(legacyPrefix.length);
      final target = '$v2Prefix$suffix';
      if (prefs.containsKey(target)) continue;
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        await prefs.setString(target, raw);
      }
    }
  }
}
