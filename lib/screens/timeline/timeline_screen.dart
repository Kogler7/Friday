import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/activity/hourly_record.dart';
import '../../models/event/todo_item.dart';
import '../../models/status/status_record_data.dart';
import '../../services/dev_sample_data.dart';
import '../../services/dev_todo_sample.dart';
import '../../services/status_data_source.dart';
import '../../services/status_preset_storage.dart';
import '../../services/storage_service.dart';
import '../../services/todo_storage_service.dart';
import '../../widgets/timeline/timeline.dart';
import '../../widgets/todo_edit_sheet.dart';
import '../status/batch_set_sheet.dart';
import '../status/preset_management_screen.dart';
import '../status/scheduled_dnd_sheet.dart';
import '../status/status_record_form_sheet.dart';
import '../status/status_record_tile.dart';

/// 时间轴页：左滑日程时间轴，右滑状态时间轴（过去24小时活动状态列表）
class TimelineScreen extends StatefulWidget {
  final void Function(List<Widget> actions)? onAppBarActionsReady;

  const TimelineScreen({super.key, this.onAppBarActionsReady});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final PageController _pageController = PageController(initialPage: 1);
  int _currentPage = 1;

  // 状态时间轴
  List<HourlyRecord> _records24h = [];
  final Set<DateTime> _selectedSlots = {};
  bool _selectionMode = false;

  // 日程时间轴
  List<TodoItem> _todoItems = [];
  bool _labelsExpanded = false;
  Offset? _dragStart;
  bool _useTestData = false;
  final TodoTimelineController _timelineController = TodoTimelineController();

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadTodos();
    StatusDataSource.useTestData.addListener(_onStatusDataSourceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyAppBarActions());
  }

  @override
  void dispose() {
    StatusDataSource.useTestData.removeListener(_onStatusDataSourceChanged);
    _pageController.dispose();
    _timelineController.dispose();
    super.dispose();
  }

  void _onStatusDataSourceChanged() {
    _loadStatus();
    if (_currentPage == 0) _notifyAppBarActions();
  }

  void _notifyAppBarActions() {
    widget.onAppBarActionsReady?.call(_buildAppBarActions());
  }

  List<Widget> _buildAppBarActions() {
    if (_currentPage == 0) {
      return [
        IconButton(
          icon: const Icon(Icons.bookmark_outlined),
          tooltip: '预设管理',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const PresetManagementScreen(),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.edit_calendar),
          tooltip: '批量设置',
          onPressed: () => showBatchSetSheet(context, _loadStatus),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) async {
            if (v == 'fill_sample') {
              await DevSampleData.insertSampleData();
              _loadStatus();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已填充示例')));
              }
            } else if (v == 'clear_range' || v == 'clear_all') {
              await _clearStatusData(v);
            } else if (v == 'data_switch') {
              StatusDataSource.useTestData.value =
                  !StatusDataSource.useTestData.value;
              if (StatusDataSource.isTestData) {
                await StatusPresetStorage.ensureBuiltInPresets();
              }
              _loadStatus();
            }
          },
          itemBuilder: (_) {
            return [
              const PopupMenuItem(value: 'clear_range', child: Text('清空时间范围')),
              const PopupMenuItem(value: 'clear_all', child: Text('全部清空')),
              if (kDebugMode) ...[
                const PopupMenuDivider(),
                if (StatusDataSource.isTestData)
                  const PopupMenuItem(
                      value: 'fill_sample', child: Text('填充示例数据')),
                const PopupMenuItem(value: 'data_switch', child: Text('切换数据源')),
              ],
            ];
          },
        ),
      ];
    }
    final theme = Theme.of(context);
    return [
      IconButton(
        icon: const Icon(Icons.refresh, size: 22),
        onPressed: () {
          _loadTodos();
          _notifyAppBarActions();
        },
        tooltip: '刷新',
      ),
      IconButton(
        icon: const Icon(Icons.restore, size: 22),
        onPressed: _timelineController.reset,
        tooltip: '还原',
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
            setState(() {
              _useTestData = !_useTestData;
              _loadTodos();
            });
            WidgetsBinding.instance.addPostFrameCallback((_) => _notifyAppBarActions());
          },
        ),
    ];
  }

  Future<void> _clearStatusData(String mode) async {
    if (mode == 'clear_range') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (range != null) {
        await StorageService.clearRecordsInRange(range.start, range.end);
        _loadStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空')));
        }
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('全部清空'),
          content: Text(
              '确定清空当前${StatusDataSource.isTestData ? '测试' : '用户'}数据源的所有记录？'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('清空')),
          ],
        ),
      );
      if (ok == true) {
        await StorageService.clearAllRecords();
        _loadStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空')));
        }
      }
    }
  }

  void _loadStatus() {
    if (!mounted) return;
    setState(() {
      _records24h = _getRecords24h();
    });
  }

  List<HourlyRecord> _getRecords24h() {
    final end = DateTime.now();
    final start = end.subtract(const Duration(hours: 24));
    final list = StorageService.getRecordsInRange(start, end);
    list.sort((a, b) => b.hourStart.compareTo(a.hourStart));
    return list;
  }

  void _loadTodos() {
    setState(() {
      _todoItems = _useTestData
          ? List.from(DevTodoSample.getSampleTodos())
          : TodoStorageService.getTodos();
    });
  }

  Widget _buildStatusTimelinePage() {
    return RefreshIndicator(
      onRefresh: () async => _loadStatus(),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('过去24小时',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (_selectionMode) ...[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectionMode = false;
                          _selectedSlots.clear();
                        });
                      },
                      child: const Text('取消'),
                    ),
                    if (_selectedSlots.isNotEmpty)
                      TextButton(
                        onPressed: _batchEditSelected,
                        child: Text('批量修改 (${_selectedSlots.length})'),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (_records24h.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('暂无记录')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final r = _records24h[i];
                    final selected = _selectedSlots.contains(r.hourStart);
                    return StatusRecordTile(
                      key: ValueKey(r.hourStart),
                      record: r,
                      selectionMode: _selectionMode,
                      selected: selected,
                      onTap: () {
                        if (_selectionMode) {
                          setState(() {
                            if (selected) {
                              _selectedSlots.remove(r.hourStart);
                            } else {
                              _selectedSlots.add(r.hourStart);
                            }
                          });
                        } else {
                          _editStatusRecord(r);
                        }
                      },
                      onLongPress: () {
                        if (!_selectionMode) {
                          setState(() {
                            _selectionMode = true;
                            _selectedSlots.add(r.hourStart);
                          });
                        }
                      },
                    );
                  },
                  childCount: _records24h.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _editStatusRecord(HourlyRecord r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatusRecordFormSheet(
        initialData: r.data,
        onSubmit: (data) {
          Navigator.of(ctx).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await StorageService.saveRecord(
                HourlyRecord(hourStart: r.hourStart, data: data));
            if (mounted) _loadStatus();
          });
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _batchEditSelected() async {
    if (_selectedSlots.isEmpty) return;
    final slots = Set<DateTime>.from(_selectedSlots);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _PresetSelectSheet(
        onSelect: (data) {
          Navigator.pop(ctx);
          _applyPresetToSlots(slots, data);
        },
      ),
    );
  }

  void _applyPresetToSlots(Set<DateTime> slots, StatusRecordData preset) async {
    for (final slot in slots) {
      await StorageService.saveRecord(
          HourlyRecord(hourStart: slot, data: preset));
    }
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedSlots.clear();
      _loadStatus();
    });
  }

  Widget _buildScheduleTimelinePage() {
    return Listener(
      onPointerDown: (e) => _dragStart = e.position,
      onPointerMove: (e) {
        if (_currentPage == 1 && _dragStart != null) {
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
        items: _todoItems,
        today: DateTime.now(),
        onItemTap: (item) => _openTodoEditSheet(item),
        controller: _timelineController,
        labelsExpanded: _labelsExpanded,
      ),
    );
  }

  void _openTodoEditSheet(TodoItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TodoEditSheet(
        item: item,
        onSave: (updated) async {
          if (_useTestData) {
            setState(() {
              final i = _todoItems.indexWhere((e) => e.id == updated.id);
              if (i >= 0) {
                _todoItems[i] = updated;
              } else {
                _todoItems.insert(0, updated);
              }
            });
            return;
          }
          await TodoStorageService.updateTodoItem(updated);
          _loadTodos();
        },
        onDelete: () async {
          if (_useTestData) {
            setState(() => _todoItems.removeWhere((e) => e.id == item.id));
            return;
          }
          await TodoStorageService.deleteTodo(item.id);
          _loadTodos();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) {
          setState(() => _currentPage = i);
          _notifyAppBarActions();
        },
        physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
        children: [
          _buildStatusTimelinePage(),
          _buildScheduleTimelinePage(),
        ],
      ),
      floatingActionButton: _currentPage == 0
          ? FloatingActionButton(
              onPressed: () => showScheduledDndSheet(context),
              tooltip: '预定免打扰',
              shape: const CircleBorder(),
              child: const Icon(Icons.do_not_disturb_on_total_silence),
            )
          : null,
    );
  }
}

class _PresetSelectSheet extends StatelessWidget {
  final void Function(StatusRecordData data) onSelect;

  const _PresetSelectSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final presets = StatusPresetStorage.getAll();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('选择预设应用到选中记录',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ...presets.map((p) => ListTile(
                leading: Icon(p.icon, color: p.color),
                title: Text(p.name),
                onTap: () => onSelect(p.data.copyWith(presetId: p.id)),
              )),
        ],
      ),
    );
  }
}
