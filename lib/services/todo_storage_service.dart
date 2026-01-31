import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo_item.dart';

const String _keyTodo = 'planplus_todo';

/// 待办本地存储
class TodoStorageService {
  TodoStorageService._();
  static late final SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static List<TodoItem> _load() {
    final jsonStr = _prefs.getString(_keyTodo);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _save(List<TodoItem> items) async {
    final list = items.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyTodo, jsonEncode(list));
  }

  /// 获取全部待办（按创建时间倒序，未完成在前）
  static List<TodoItem> getTodos() {
    final list = _load();
    list.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// 添加待办（可选 DDL、提醒、日程）
  static Future<TodoItem> addTodo(
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
    final list = _load();
    list.insert(0, item);
    await _save(list);
    return item;
  }

  /// 插入一条待办（用于从编辑弹窗保存的新项）
  static Future<void> addTodoItem(TodoItem item) async {
    final list = _load();
    list.insert(0, item);
    await _save(list);
  }

  /// 切换完成状态
  static Future<void> toggleTodo(String id) async {
    final list = _load();
    final index = list.indexWhere((e) => e.id == id);
    if (index < 0) return;
    list[index] = list[index].copyWith(completed: !list[index].completed);
    await _save(list);
  }

  /// 更新标题
  static Future<void> updateTodo(String id, String title) async {
    final list = _load();
    final index = list.indexWhere((e) => e.id == id);
    if (index < 0) return;
    list[index] = list[index].copyWith(title: title.trim());
    await _save(list);
  }

  /// 整条更新（标题、DDL、提醒、日程等）
  static Future<void> updateTodoItem(TodoItem item) async {
    final list = _load();
    final index = list.indexWhere((e) => e.id == item.id);
    if (index < 0) return;
    list[index] = item;
    await _save(list);
  }

  /// 删除待办
  static Future<void> deleteTodo(String id) async {
    final list = _load();
    list.removeWhere((e) => e.id == id);
    await _save(list);
  }
}
