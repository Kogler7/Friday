import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_config.dart';
import '../models/todo_item.dart';
import '../services/dev_todo_sample.dart';
import '../services/todo_storage_service.dart';
import '../widgets/todo_edit_sheet.dart';
import '../widgets/timeline/timeline.dart';

/// 筛选类型
enum _EventFilter {
  all,
  active,
  completed,
}

/// 事件页当前视图：时间轴 / 列表
enum _EventView {
  timeline,
  list,
}

/// 事件页：用于记录事件（原 TodoScreen）
class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  List<TodoItem> _items = [];
  _EventFilter _filter = _EventFilter.all;
  _EventView _view = _EventView.list;
  bool _useTestData = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      if (_useTestData) {
        _items = List.from(DevTodoSample.getSampleTodos());
      } else {
        _items = TodoStorageService.getTodos();
      }
    });
  }

  void _toggleTestData() {
    setState(() {
      _useTestData = !_useTestData;
      if (_useTestData) {
        _items = List.from(DevTodoSample.getSampleTodos());
      } else {
        _items = TodoStorageService.getTodos();
      }
    });
  }

  List<TodoItem> get _filteredItems {
    switch (_filter) {
      case _EventFilter.active:
        return _items.where((e) => !e.completed).toList();
      case _EventFilter.completed:
        return _items.where((e) => e.completed).toList();
      case _EventFilter.all:
        return _items;
    }
  }

  Future<void> _toggle(TodoItem item) async {
    if (_useTestData) {
      setState(() {
        final i = _items.indexWhere((e) => e.id == item.id);
        if (i >= 0) _items[i] = item.copyWith(completed: !item.completed);
      });
      return;
    }
    await TodoStorageService.toggleTodo(item.id);
    _load();
  }

  Future<void> _delete(String id) async {
    if (_useTestData) {
      setState(() => _items.removeWhere((e) => e.id == id));
      return;
    }
    await TodoStorageService.deleteTodo(id);
    _load();
  }

  Widget _buildTimelineBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: TodoTimeline(
              items: _items,
              today: DateTime.now(),
              onRefresh: _load,
              onItemTap: (item) => _openEditSheet(item),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListBody(List<TodoItem> filtered, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                label: '全部',
                selected: _filter == _EventFilter.all,
                count: _items.length,
                onTap: () => setState(() => _filter = _EventFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '未完成',
                selected: _filter == _EventFilter.active,
                count: _items.where((e) => !e.completed).length,
                onTap: () => setState(() => _filter = _EventFilter.active),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '已完成',
                selected: _filter == _EventFilter.completed,
                count: _items.where((e) => e.completed).length,
                onTap: () => setState(() => _filter = _EventFilter.completed),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _filter == _EventFilter.all
                        ? '暂无事件，点击右下角 + 添加'
                        : _filter == _EventFilter.active
                            ? '没有未完成项'
                            : '没有已完成项',
                    style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: theme.colorScheme.errorContainer,
                        child: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      onDismissed: (_) => _delete(item.id),
                      child: _EventListTile(
                        item: item,
                        theme: theme,
                        onToggle: () => _toggle(item),
                        onTap: () => _openEditSheet(item),
                        onDelete: () => _delete(item.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _openEditSheet([TodoItem? item]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TodoEditSheet(
        item: item,
        onSave: (updated) async {
          if (_useTestData) {
            setState(() {
              final i = _items.indexWhere((e) => e.id == updated.id);
              if (i >= 0) {
                _items[i] = updated;
              } else {
                _items.insert(0, updated);
              }
            });
            return;
          }
          if (item == null) {
            await TodoStorageService.addTodoItem(updated);
          } else {
            await TodoStorageService.updateTodoItem(updated);
          }
          _load();
        },
        onDelete: item != null
            ? () async {
                if (_useTestData) {
                  setState(() => _items.removeWhere((e) => e.id == item.id));
                  return;
                }
                await TodoStorageService.deleteTodo(item.id);
                _load();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<_EventView>(
                    segments: const [
                      ButtonSegment<_EventView>(
                        value: _EventView.timeline,
                        icon: Icon(Icons.schedule, size: 20),
                        label: Text('时间轴'),
                      ),
                      ButtonSegment<_EventView>(
                        value: _EventView.list,
                        icon: Icon(Icons.list, size: 20),
                        label: Text('事件列表'),
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (Set<_EventView> s) {
                      if (s.isNotEmpty) setState(() => _view = s.first);
                    },
                  ),
                ),
                if (kIsDevMode)
                  IconButton(
                    icon: Icon(
                      _useTestData ? Icons.folder_special : Icons.folder_outlined,
                      color: _useTestData ? theme.colorScheme.primary : null,
                    ),
                    tooltip: _useTestData ? '测试数据' : '真实数据',
                    onPressed: _toggleTestData,
                  ),
              ],
            ),
          ),
          Expanded(
            child: _view == _EventView.timeline
                ? _buildTimelineBody()
                : _buildListBody(filtered, theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditSheet(),
        tooltip: '添加事件',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EventListTile extends StatelessWidget {
  final TodoItem item;
  final ThemeData theme;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EventListTile({
    required this.item,
    required this.theme,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
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
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
        onPressed: onDelete,
        tooltip: '删除',
      ),
      onTap: onTap,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text('$label${count > 0 ? ' ($count)' : ''}'),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}
