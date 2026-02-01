import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/status/scheduled_dnd.dart';
import 'status_data_source.dart';

String get _keyDnd => StatusDataSource.key('scheduled_dnd');

class ScheduledDndStorage {
  ScheduledDndStorage._();
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static List<ScheduledDnd> getAll() {
    final jsonStr = _prefs.getString(_keyDnd);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => ScheduledDnd.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static ScheduledDnd? getActiveFor(DateTime slot) {
    for (final d in getAll()) {
      if (d.contains(slot)) return d;
    }
    return null;
  }

  static Future<void> save(ScheduledDnd dnd) async {
    final list = getAll();
    final idx = list.indexWhere((d) => d.id == dnd.id);
    if (idx >= 0) {
      list[idx] = dnd;
    } else {
      list.add(dnd);
    }
    await _prefs.setString(
      _keyDnd,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> delete(String id) async {
    final list = getAll().where((d) => d.id != id).toList();
    await _prefs.setString(
      _keyDnd,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }
}
