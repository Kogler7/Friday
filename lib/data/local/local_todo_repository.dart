import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/todo_repository.dart';
import '../../models/event/todo_item.dart';
import 'legacy_readonly_guard.dart';

class LocalTodoRepository implements TodoRepository {
  static const String _keyTodoV2 = '${LegacyReadOnlyGuard.v2Prefix}todo_items';
  static const String _keyTodoLegacy = 'friday_todo';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<TodoItem> _loadV2() {
    final jsonStr = _prefs.getString(_keyTodoV2);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<TodoItem> exportAll() {
    final v2 = _loadV2();
    if (v2.isNotEmpty) return v2;
    return _loadLegacy();
  }

  Future<void> _saveV2(List<TodoItem> items) async {
    final list = items.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyTodoV2, jsonEncode(list));
  }

  Future<List<TodoItem>> _loadWritableBase() async {
    final v2 = _loadV2();
    if (v2.isNotEmpty || _prefs.containsKey(_keyTodoV2)) return v2;
    final legacy = _loadLegacy();
    if (legacy.isNotEmpty) {
      await _saveV2(legacy);
    }
    return legacy;
  }

  List<TodoItem> _loadLegacy() {
    final jsonStr = _prefs.getString(_keyTodoLegacy);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  List<TodoItem> getTodos() {
    final v2 = _loadV2();
    final list = v2.isNotEmpty ? v2 : _loadLegacy();
    list.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  @override
  Future<TodoItem> addTodo(
    String title, {
    DateTime? dueDate,
    DateTime? reminderAt,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
  }) async {
    final item = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      completed: false,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      reminderAt: reminderAt,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
    );
    await addTodoItem(item);
    return item;
  }

  @override
  Future<void> addTodoItem(TodoItem item) async {
    final list = await _loadWritableBase();
    list.insert(0, item);
    await _saveV2(list);
  }

  @override
  Future<void> toggleTodo(String id) async {
    final list = await _loadWritableBase();
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(completed: !list[idx].completed);
    await _saveV2(list);
  }

  @override
  Future<void> updateTodo(String id, String title) async {
    final list = await _loadWritableBase();
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(title: title.trim());
    await _saveV2(list);
  }

  @override
  Future<void> updateTodoItem(TodoItem item) async {
    final list = await _loadWritableBase();
    final idx = list.indexWhere((e) => e.id == item.id);
    if (idx < 0) return;
    list[idx] = item;
    await _saveV2(list);
  }

  @override
  Future<void> deleteTodo(String id) async {
    final list = await _loadWritableBase();
    list.removeWhere((e) => e.id == id);
    await _saveV2(list);
  }
}
