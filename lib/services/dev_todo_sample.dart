import 'package:flutter/foundation.dart';

import '../models/todo_item.dart';

/// 开发阶段待办示例数据：仅 [kDebugMode] 下用于时间轴/列表演示。
class DevTodoSample {
  DevTodoSample._();

  /// 返回内置测试数据（今日 DDL/提醒/日程），用于一键切换「测试数据」模式。
  static List<TodoItem> getSampleTodos() {
    if (!kDebugMode) return [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      TodoItem(
        id: 'dev_todo_1',
        title: '晨会同步',
        completed: false,
        createdAt: today.add(const Duration(hours: 7)),
        dueDate: today.add(const Duration(hours: 18)),
        reminderAt: today.add(const Duration(hours: 8)),
        scheduledStart: today.add(const Duration(hours: 9)),
        scheduledEnd: today.add(const Duration(hours: 9, minutes: 30)),
      ),
      TodoItem(
        id: 'dev_todo_2',
        title: '需求评审',
        completed: false,
        createdAt: today.add(const Duration(hours: 8)),
        dueDate: today.add(const Duration(hours: 17)),
        reminderAt: today.add(const Duration(hours: 9)),
        scheduledStart: today.add(const Duration(hours: 10)),
        scheduledEnd: today.add(const Duration(hours: 11, minutes: 30)),
      ),
      TodoItem(
        id: 'dev_todo_3',
        title: '写周报',
        completed: false,
        createdAt: today.add(const Duration(hours: 9)),
        dueDate: today,
        reminderAt: today.add(const Duration(hours: 16)),
        scheduledStart: today.add(const Duration(hours: 14)),
        scheduledEnd: today.add(const Duration(hours: 15)),
      ),
      TodoItem(
        id: 'dev_todo_4',
        title: 'DDL 今日截止',
        completed: false,
        createdAt: today.add(const Duration(hours: 10)),
        dueDate: today.add(const Duration(hours: 23, minutes: 59)),
        reminderAt: today.add(const Duration(hours: 12)),
        scheduledStart: null,
        scheduledEnd: null,
      ),
      TodoItem(
        id: 'dev_todo_5',
        title: '仅提醒今日',
        completed: true,
        createdAt: today.add(const Duration(hours: 6)),
        dueDate: null,
        reminderAt: today.add(const Duration(hours: 8, minutes: 30)),
        scheduledStart: null,
        scheduledEnd: null,
      ),
    ];
  }
}
