import 'package:flutter/material.dart';

import '../../common/slidable_action_tile.dart';
import '../../constants/app_config.dart';
import '../../models/event/todo_item.dart';
import '../../services/dev_todo_sample.dart';
import '../../services/todo_storage_service.dart';
import '../../widgets/todo_edit_sheet.dart';
import '../../widgets/timeline/timeline.dart';
import 'event_filter_chip.dart';
import 'event_list_tile.dart';

/// 筛选类型
enum _EventFilter {
  all,
  active,
  completed,
}

/// 事件页：用于记录事件（原 TodoScreen）
/// 左滑切换至事件列表，时间轴页右滑展开日期标签
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

  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  bool _labelsExpanded = false;
  Offset? _dragStart;
  final TodoTimelineController _timelineController = TodoTimelineController();

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyAppBarActions());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timelineController.dispose();
    super.dispose();
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
      IconButton(
        icon: const Icon(Icons.restore, size: 22),
        onPressed: _timelineController.reset,
        tooltip: '还原',
      ),
      if (kIsDevMode)
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

  Widget _buildTimelineBody() {
    return Listener(
      onPointerDown: (e) => _dragStart = e.position,
      onPointerMove: (e) {
        if (_currentPage == 0 && _dragStart != null) {
          final delta = e.position - _dragStart!;
          final shouldExpand = delta.dx > 60 && delta.dx > delta.dy.abs();
          if (_labelsExpanded != shouldExpand) {
            setState(() => _labelsExpanded = shouldExpand);
          }
        }
      },
      onPointerUp: (_) {
        if (_labelsExpanded) setState(() => _labelsExpanded = false);
        _dragStart = null;
      },
      onPointerCancel: (_) {
        if (_labelsExpanded) setState(() => _labelsExpanded = false);
        _dragStart = null;
      },
      child: TodoTimeline(
        items: _items,
        today: DateTime.now(),
        onItemTap: (item) => _openEditSheet(item),
        controller: _timelineController,
        labelsExpanded: _labelsExpanded,
      ),
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
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentPage = i),
        physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
        children: [
          _buildTimelineBody(),
          _buildListBody(filtered, theme),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditSheet(),
        tooltip: '添加事件',
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
