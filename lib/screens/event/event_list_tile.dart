import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/event/todo_item.dart';

/// 事件列表项：标题、副信息（DDL/提醒/日程）、完成勾选
class EventListTile extends StatelessWidget {
  final TodoItem item;
  final ThemeData theme;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const EventListTile({
    super.key,
    required this.item,
    required this.theme,
    required this.onToggle,
    required this.onTap,
  });

  static final _dateTimeFmt = DateFormat('MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    if (item.dueDate != null) {
      lines.add('DDL ${_dateTimeFmt.format(item.dueDate!)}');
    }
    if (item.reminderAt != null) {
      lines.add('提醒 ${_dateTimeFmt.format(item.reminderAt!)}');
    }
    if (item.scheduledStart != null || item.scheduledEnd != null) {
      final start = item.scheduledStart != null ? _dateTimeFmt.format(item.scheduledStart!) : '?';
      final end = item.scheduledEnd != null ? _dateTimeFmt.format(item.scheduledEnd!) : '?';
      lines.add('日程 $start — $end');
    }
    final subtitle = lines.isEmpty ? null : lines.join(' · ');

    return ListTile(
      leading: Checkbox(
        value: item.completed,
        onChanged: (_) => onToggle(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          decoration: item.completed ? TextDecoration.lineThrough : null,
          color: item.completed ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: onTap,
    );
  }
}
