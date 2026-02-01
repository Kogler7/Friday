import 'package:flutter/material.dart';

import '../../constants/app_config.dart';
import '../../models/activity/hourly_record.dart';
import '../../models/status/status_record_data.dart';
import '../../services/dev_sample_data.dart';
import '../../services/status_preset_storage.dart';
import '../../services/settings_service.dart';
import '../../services/status_data_source.dart';
import '../../services/storage_service.dart';
import 'batch_set_sheet.dart';
import 'preset_management_screen.dart';
import 'scheduled_dnd_sheet.dart';
import 'status_record_form_sheet.dart';
import 'status_record_tile.dart';

/// 状态页：维度统计图、过去24小时倒序列表、编辑/批量编辑
class StatusScreen extends StatefulWidget {
  final void Function(List<Widget> actions)? onAppBarActionsReady;

  const StatusScreen({super.key, this.onAppBarActionsReady});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<HourlyRecord> _records24h = [];
  final Set<DateTime> _selectedSlots = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _load();
    StatusDataSource.useTestData.addListener(_onDataSourceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onAppBarActionsReady?.call(_buildAppBarActions());
      }
    });
  }

  @override
  void dispose() {
    StatusDataSource.useTestData.removeListener(_onDataSourceChanged);
    super.dispose();
  }

  void _onDataSourceChanged() {
    _load();
    widget.onAppBarActionsReady?.call(_buildAppBarActions());
  }

  List<Widget> _buildAppBarActions() {
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
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (v) async {
          if (v == 'batch') showBatchSetSheet(context, _load);
          else if (v == 'dnd') showScheduledDndSheet(context);
          else if (v == 'fill_sample') {
            await DevSampleData.insertSampleData();
            _load();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已填充示例')));
          } else if (v == 'clear_range' || v == 'clear_all') await _clearData(v);
        },
        itemBuilder: (_) {
          final items = <PopupMenuEntry<String>>[
            const PopupMenuItem(value: 'batch', child: Text('批量设置')),
            const PopupMenuItem(value: 'dnd', child: Text('预定免打扰')),
          ];
          if (kIsDevMode) {
            items.addAll([
              const PopupMenuDivider(),
              if (StatusDataSource.isTestData)
                const PopupMenuItem(value: 'fill_sample', child: Text('填充示例数据')),
              const PopupMenuItem(value: 'clear_range', child: Text('清空时间范围')),
              const PopupMenuItem(value: 'clear_all', child: Text('全部清空')),
            ]);
          }
          return items;
        },
      ),
    ];
  }

  Future<void> _clearData(String mode) async {
    if (mode == 'clear_range') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (range != null) {
        await StorageService.clearRecordsInRange(range.start, range.end);
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空')));
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('全部清空'),
          content: Text('确定清空当前${StatusDataSource.isTestData ? '测试' : '用户'}数据源的所有记录？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
          ],
        ),
      );
      if (ok == true) {
        await StorageService.clearAllRecords();
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空')));
      }
    }
  }

  void _load() {
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                      children: [
                        Text('过去24小时', style: Theme.of(context).textTheme.titleMedium),
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
                              onPressed: () => _batchEditSelected(),
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
                              if (selected) _selectedSlots.remove(r.hourStart);
                              else _selectedSlots.add(r.hourStart);
                            });
                          } else {
                            _editRecord(r);
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
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (kIsDevMode) _buildDataSwitchButton(),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () => _showAddRecordSheet(context),
            tooltip: '添加记录',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSwitchButton() {
    final isTest = StatusDataSource.isTestData;
    return FloatingActionButton.small(
      onPressed: () async {
        StatusDataSource.useTestData.value = !StatusDataSource.useTestData.value;
        if (StatusDataSource.isTestData) {
          await StatusPresetStorage.ensureBuiltInPresets();
        }
        _load();
      },
      tooltip: isTest ? '切换回用户数据' : '切换到测试数据',
      heroTag: 'data_switch',
      child: Icon(isTest ? Icons.swap_horiz : Icons.science_outlined),
    );
  }

  void _showAddRecordSheet(BuildContext context) {
    final unitMin = SettingsService.isInitialized ? SettingsService.current.statUnitMinutes : 20;
    final now = DateTime.now();
    final totalMin = now.hour * 60 + now.minute;
    final rounded = (totalMin ~/ unitMin) * unitMin;
    final slot = DateTime(now.year, now.month, now.day, rounded ~/ 60, rounded % 60, 0, 0);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatusRecordFormSheet(
        initialData: const StatusRecordData(),
        onSubmit: (data) {
          Navigator.of(ctx).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await StorageService.saveRecord(HourlyRecord(hourStart: slot, data: data));
            if (mounted) _load();
          });
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _editRecord(HourlyRecord r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatusRecordFormSheet(
        initialData: r.data,
        onSubmit: (data) {
          Navigator.of(ctx).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await StorageService.saveRecord(HourlyRecord(hourStart: r.hourStart, data: data));
            if (mounted) _load();
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
      await StorageService.saveRecord(HourlyRecord(hourStart: slot, data: preset));
    }
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedSlots.clear();
      _load();
    });
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
          Text('选择预设应用到选中记录', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ...presets.map((p) => ListTile(
            leading: Icon(p.icon, color: p.color),
            title: Text(p.name),
            onTap: () => onSelect(p.data),
          )),
        ],
      ),
    );
  }
}

// Need StatusPresetStorage import