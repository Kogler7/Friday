import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event/todo_item.dart';

/// 待办编辑/添加底部弹窗：标题、DDL、当天提醒、日程、删除
class TodoEditSheet extends StatefulWidget {
  final TodoItem? item;
  final void Function(TodoItem) onSave;
  final void Function()? onDelete;

  const TodoEditSheet({
    super.key,
    this.item,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<TodoEditSheet> createState() => _TodoEditSheetState();
}

class _TodoEditSheetState extends State<TodoEditSheet> {
  late final TextEditingController _titleController;
  DateTime? _dueDate;
  DateTime? _reminderAt;
  DateTime? _scheduledStart;
  DateTime? _scheduledEnd;

  static final DateFormat _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _dueDate = widget.item?.dueDate;
    _reminderAt = widget.item?.reminderAt;
    _scheduledStart = widget.item?.scheduledStart;
    _scheduledEnd = widget.item?.scheduledEnd;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDateAndTime(
    DateTime? initial,
    String label, {
    bool dateOnly = false,
  }) async {
    var date = initial ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null) return;
    if (dateOnly) {
      setState(() {
        if (label == '截止日期') _dueDate = pickedDate;
      });
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date),
    );
    if (pickedTime == null) return;
    date = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      if (label == '当天提醒') _reminderAt = date;
      if (label == '开始时间') _scheduledStart = date;
      if (label == '结束时间') _scheduledEnd = date;
    });
  }

  Future<void> _pickDueDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (d == null) return;
    TimeOfDay? t;
    if (_dueDate != null) {
      t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dueDate!),
      );
    } else {
      t = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 23, minute: 59),
      );
    }
    if (t == null) {
      setState(() => _dueDate = d);
      return;
    }
    final time = t;
    setState(() {
      _dueDate = DateTime(d.year, d.month, d.day, time.hour, time.minute);
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    if (widget.item != null) {
      widget.onSave(widget.item!.copyWith(
        title: title,
        dueDate: _dueDate,
        reminderAt: _reminderAt,
        scheduledStart: _scheduledStart,
        scheduledEnd: _scheduledEnd,
      ));
    } else {
      final newItem = TodoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        completed: false,
        createdAt: DateTime.now(),
        dueDate: _dueDate,
        reminderAt: _reminderAt,
        scheduledStart: _scheduledStart,
        scheduledEnd: _scheduledEnd,
      );
      widget.onSave(newItem);
    }
    Navigator.of(context).pop();
  }

  void _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除待办'),
        content: const Text('确定要删除这条待办吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      widget.onDelete?.call();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.item != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? '编辑待办' : '添加待办',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '待办内容',
                border: OutlineInputBorder(),
              ),
              autofocus: !isEdit,
            ),
            const SizedBox(height: 16),
            // DDL
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('截止日期'),
              subtitle: Text(_dueDate != null ? _dateTimeFmt.format(_dueDate!) : '未设置'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar),
                    onPressed: _pickDueDate,
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              tileColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
            // 当天提醒
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('当天提醒'),
              subtitle: Text(_reminderAt != null ? _dateTimeFmt.format(_reminderAt!) : '未设置'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_reminderAt != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _reminderAt = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar),
                    onPressed: () => _pickDateAndTime(_reminderAt, '当天提醒'),
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              tileColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
            // 日程安排
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('日程安排'),
              subtitle: Text(
                _scheduledStart != null || _scheduledEnd != null
                    ? '${_scheduledStart != null ? _dateTimeFmt.format(_scheduledStart!) : '?'} — ${_scheduledEnd != null ? _dateTimeFmt.format(_scheduledEnd!) : '?'}'
                    : '未设置',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_scheduledStart != null || _scheduledEnd != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _scheduledStart = null;
                        _scheduledEnd = null;
                      }),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar),
                    onPressed: () async {
                      await _pickDateAndTime(_scheduledStart, '开始时间');
                      if (!mounted) return;
                      await _pickDateAndTime(_scheduledEnd ?? _scheduledStart, '结束时间');
                    },
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              tileColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (isEdit && widget.onDelete != null) ...[
                  TextButton.icon(
                    onPressed: _confirmDelete,
                    icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                    label: Text('删除', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                  const Spacer(),
                ] else
                  const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
