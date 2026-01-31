import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_config.dart';
import '../models/todo_item.dart';
import '../services/dev_todo_sample.dart';
import '../services/todo_storage_service.dart';
import '../widgets/todo_edit_sheet.dart';
import '../widgets/timeline/timeline.dart';

/// 筛选类型
enum _TodoFilter {
  all,
  active,
  completed,
}

/// 待办页当前视图：时间轴 / 列表（只构建当前选中的，避免 IndexedStack + Expanded 导致崩溃）
enum _TodoView {
  timeline,
  list,
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<TodoItem> _items = [];
  _TodoFilter _filter = _TodoFilter.all;
  _TodoView _view = _TodoView.list;
  /// 开发模式：true=显示内置测试数据，false=真实存储数据
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
      case _TodoFilter.active:
        return _items.where((e) => !e.completed).toList();
      case _TodoFilter.completed:
        return _items.where((e) => e.completed).toList();
      case _TodoFilter.all:
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

  /// 时间轴页：单页只建这一块，用 Expanded+SingleChildScrollView 给足有界高度，避免崩溃
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

  /// 待办列表页：筛选 + 列表
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
                selected: _filter == _TodoFilter.all,
                count: _items.length,
                onTap: () => setState(() => _filter = _TodoFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '未完成',
                selected: _filter == _TodoFilter.active,
                count: _items.where((e) => !e.completed).length,
                onTap: () => setState(() => _filter = _TodoFilter.active),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '已完成',
                selected: _filter == _TodoFilter.completed,
                count: _items.where((e) => e.completed).length,
                onTap: () => setState(() => _filter = _TodoFilter.completed),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _filter == _TodoFilter.all
                        ? '暂无待办，点击右上角 + 添加'
                        : _filter == _TodoFilter.active
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
                      child: _TodoListTile(
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
      appBar: AppBar(
        title: const Text('待办'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          if (kIsDevMode)
            IconButton(
              icon: Icon(
                _useTestData ? Icons.folder_special : Icons.folder_outlined,
                color: _useTestData ? theme.colorScheme.primary : null,
              ),
              tooltip: _useTestData ? '当前：测试数据（点击切回真实数据）' : '当前：真实数据（点击切换测试数据）',
              onPressed: _toggleTestData,
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '添加待办（含 DDL、提醒、日程）',
            onPressed: () => _openEditSheet(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<_TodoView>(
              segments: const [
                ButtonSegment<_TodoView>(
                  value: _TodoView.timeline,
                  icon: Icon(Icons.schedule, size: 20),
                  label: Text('时间轴'),
                ),
                ButtonSegment<_TodoView>(
                  value: _TodoView.list,
                  icon: Icon(Icons.list, size: 20),
                  label: Text('待办列表'),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (Set<_TodoView> s) {
                if (s.isNotEmpty) setState(() => _view = s.first);
              },
            ),
          ),
        ),
      ),
      body: _view == _TodoView.timeline ? _buildTimelineBody() : _buildListBody(filtered, theme),
    );
  }
}

class _TodoListTile extends StatelessWidget {
  final TodoItem item;
  final ThemeData theme;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TodoListTile({
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
