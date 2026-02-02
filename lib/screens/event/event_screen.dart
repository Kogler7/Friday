import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../common/slidable_action_tile.dart';
import '../../models/event/todo_item.dart';
import '../../services/dev_todo_sample.dart';
import '../../services/todo_storage_service.dart';
import '../../widgets/todo_edit_sheet.dart';
import 'event_filter_chip.dart';
import 'event_list_tile.dart';

/// 筛选类型
enum _EventFilter {
  all,
  active,
  completed,
}

/// 日程页：仅展示待办清单，时间轴已移至「时间轴」页
class EventScreen extends StatefulWidget {
  final void Function(List<Widget> actions)? onAppBarActionsReady;

  const EventScreen({super.key, this.onAppBarActionsReady});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  List<TodoItem> _items = [];
  _EventFilter _filter = _EventFilter.all;
  bool _useTestData = false;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyAppBarActions());
  }

  void _notifyAppBarActions() {
    widget.onAppBarActionsReady?.call(_buildAppBarActions());
  }

  List<Widget> _buildAppBarActions() {
    final theme = Theme.of(context);
    return [
      IconButton(
        icon: const Icon(Icons.refresh, size: 22),
        onPressed: _load,
        tooltip: '刷新',
      ),
      if (kDebugMode)
        IconButton(
          icon: Icon(
            _useTestData ? Icons.folder_special : Icons.folder_outlined,
            size: 22,
            color: _useTestData ? theme.colorScheme.primary : null,
          ),
          tooltip: _useTestData ? '测试数据' : '真实数据',
          onPressed: () {
            _toggleTestData();
            WidgetsBinding.instance.addPostFrameCallback((_) => _notifyAppBarActions());
          },
        ),
    ];
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

  Widget _buildListBody(List<TodoItem> filtered, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              EventFilterChip(
                label: '全部',
                selected: _filter == _EventFilter.all,
                count: _items.length,
                onTap: () => setState(() => _filter = _EventFilter.all),
              ),
              const SizedBox(width: 8),
              EventFilterChip(
                label: '未完成',
                selected: _filter == _EventFilter.active,
                count: _items.where((e) => !e.completed).length,
                onTap: () => setState(() => _filter = _EventFilter.active),
              ),
              const SizedBox(width: 8),
              EventFilterChip(
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
                        ? '暂无日程，点击右下角 + 添加'
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
                    return SlidableActionTile(
                      key: Key(item.id),
                      height: 72,
                      leftAction: SwipeActionConfig(
                        icon: Icons.delete_outline,
                        backgroundColor: Colors.red,
                        onTrigger: () => _delete(item.id),
                      ),
                      rightAction: SwipeActionConfig(
                        icon: Icons.check_circle_outline,
                        backgroundColor: Colors.blue,
                        onTrigger: () => _toggle(item),
                      ),
                      child: EventListTile(
                        item: item,
                        theme: theme,
                        onToggle: () => _toggle(item),
                        onTap: () => _openEditSheet(item),
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
      body: _buildListBody(filtered, theme),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditSheet(),
        tooltip: '添加日程',
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
