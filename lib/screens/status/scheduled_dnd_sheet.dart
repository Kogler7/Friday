import 'package:flutter/material.dart';

import '../../common/slidable_action_tile.dart';
import '../../models/status/scheduled_dnd.dart';
import '../../models/status/status_preset.dart';
import '../../services/scheduled_dnd_storage.dart';
import '../../services/status_preset_storage.dart';

/// 预定免打扰管理
void showScheduledDndSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final list = ScheduledDndStorage.getAll();
          final presets = StatusPresetStorage.getAll();
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          '预定免打扰',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () =>
                              _showDndFormSheet(ctx, presets, null, () => setState(() {})),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('添加'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Text(
                              '到点自动填充，不弹窗提醒',
                              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final d = list[i];
                              return _DndSlidableTile(
                                dnd: d,
                                presets: presets,
                                onChanged: () => setState(() {}),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

String _formatDateTime(DateTime dt) {
  return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DndSlidableTile extends StatelessWidget {
  final ScheduledDnd dnd;
  final List<StatusPreset> presets;
  final VoidCallback onChanged;

  const _DndSlidableTile({
    required this.dnd,
    required this.presets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final preset = presets.where((p) => p.id == dnd.presetId).firstOrNull;
    final timeStr = dnd.recurringDaily
        ? '每日 ${dnd.start.hour.toString().padLeft(2, '0')}:${dnd.start.minute.toString().padLeft(2, '0')} - '
            '${dnd.end.hour.toString().padLeft(2, '0')}:${dnd.end.minute.toString().padLeft(2, '0')}'
        : '${_formatDateTime(dnd.start)} - ${_formatDateTime(dnd.end)}';
    final theme = Theme.of(context);
    return SlidableActionTile(
      key: ValueKey(dnd.id),
      height: 64,
      leftAction: SwipeActionConfig(
        icon: Icons.delete_outline,
        backgroundColor: theme.colorScheme.error,
        iconColor: theme.colorScheme.onError,
        onTrigger: () async {
          await ScheduledDndStorage.delete(dnd.id);
          onChanged();
        },
      ),
      rightAction: SwipeActionConfig(
        icon: dnd.recurringDaily ? Icons.repeat_on : Icons.repeat,
        backgroundColor: theme.colorScheme.primaryContainer,
        iconColor: theme.colorScheme.onPrimaryContainer,
        onTrigger: () async {
          await ScheduledDndStorage.save(dnd.copyWith(recurringDaily: !dnd.recurringDaily));
          onChanged();
        },
      ),
      child: Material(
        color: theme.colorScheme.surface,
        child: ListTile(
          leading: preset != null
              ? Icon(preset.icon, color: preset.color)
              : const Icon(Icons.notifications_off),
          title: Text(timeStr, style: const TextStyle(fontSize: 13)),
          subtitle: Text(preset?.name ?? dnd.presetId),
          trailing: dnd.recurringDaily
              ? Icon(Icons.repeat, size: 20, color: theme.colorScheme.primary)
              : const Icon(Icons.chevron_right),
          onTap: () {
            _showDndFormSheet(context, presets, dnd, onChanged);
          },
        ),
      ),
    );
  }
}

Future<void> _showDndFormSheet(
  BuildContext ctx,
  List<StatusPreset> presets,
  ScheduledDnd? existing,
  VoidCallback onChanged,
) async {
  final isEdit = existing != null;
  final now = DateTime.now();
  DateTime start = existing != null
      ? existing.start
      : DateTime(now.year, now.month, now.day, 22, 0);
  DateTime end = existing != null
      ? existing.end
      : DateTime(now.year, now.month, now.day, 7, 0);
  if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
    end = end.add(const Duration(days: 1));
  }
  bool recurringDaily = existing?.recurringDaily ?? true;
  String? presetId = existing?.presetId ?? (presets.isNotEmpty ? presets.first.id : null);

  final result = await showModalBottomSheet<bool>(
    context: ctx,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          if (presets.isNotEmpty &&
              (presetId == null || !presets.any((p) => p.id == presetId))) {
            presetId = presets.first.id;
          }
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEdit ? '编辑免打扰时段' : '添加免打扰时段',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('每日循环'),
                    subtitle: const Text('勾选后按每日时分生效，如 22:00-07:00'),
                    value: recurringDaily,
                    onChanged: (v) => setState(() => recurringDaily = v),
                  ),
                  ListTile(
                    title: const Text('开始时间'),
                    subtitle: Text(
                      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
                      );
                      if (t != null) {
                        setState(() => start = DateTime(
                              start.year,
                              start.month,
                              start.day,
                              t.hour,
                              t.minute,
                            ));
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('结束时间'),
                    subtitle: Text(
                      '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: end.hour, minute: end.minute),
                      );
                      if (t != null) {
                        setState(() {
                          end = DateTime(
                            end.year,
                            end.month,
                            end.day,
                            t.hour,
                            t.minute,
                          );
                          if (recurringDaily && end.hour == 0 && end.minute == 0) {
                            end = DateTime(
                              end.year,
                              end.month,
                              end.day,
                              23,
                              59,
                            ).add(const Duration(minutes: 1));
                          }
                        });
                      }
                    },
                  ),
                  if (!recurringDaily) ...[
                    ListTile(
                      title: const Text('开始日期'),
                      subtitle: Text(_formatDateTime(start)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: start,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (d != null) {
                          setState(() => start = DateTime(
                                d.year,
                                d.month,
                                d.day,
                                start.hour,
                                start.minute,
                              ));
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('结束日期'),
                      subtitle: Text(_formatDateTime(end)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: end.isBefore(start) ? start : end,
                          firstDate: start,
                          lastDate: DateTime.now().add(const Duration(days: 31)),
                        );
                        if (d != null) {
                          setState(() => end = DateTime(
                                d.year,
                                d.month,
                                d.day,
                                end.hour,
                                end.minute,
                              ));
                        }
                      },
                    ),
                  ],
                  if (presets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: presetId,
                      decoration: const InputDecoration(labelText: '预设'),
                      items: presets
                          .map((StatusPreset p) => DropdownMenuItem<String>(
                                value: p.id,
                                child: Text(p.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => presetId = v),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: (presetId?.isEmpty ?? true)
                            ? null
                            : () => Navigator.pop(context, true),
                        child: Text(isEdit ? '保存' : '添加'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  final pid = presetId;
  if (result == true && pid != null && pid.isNotEmpty) {
    DateTime startVal = start;
    DateTime endVal = end;
    if (recurringDaily) {
      startVal = DateTime(2000, 1, 1, start.hour, start.minute);
      endVal = DateTime(2000, 1, 1, end.hour, end.minute);
      if (endVal.isBefore(startVal) || endVal.isAtSameMomentAs(startVal)) {
        endVal = endVal.add(const Duration(days: 1));
      }
    }
    final dnd = ScheduledDnd(
      id: existing?.id ?? 'dnd_${DateTime.now().millisecondsSinceEpoch}',
      start: startVal,
      end: endVal,
      presetId: pid,
      recurringDaily: recurringDaily,
    );
    await ScheduledDndStorage.save(dnd);
    onChanged();
  }
}
