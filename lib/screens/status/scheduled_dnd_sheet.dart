import 'package:flutter/material.dart';

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
                          onPressed: () => _showAddDnd(ctx, presets, () => setState(() {})),
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
                              final preset = presets.where((p) => p.id == d.presetId).firstOrNull;
                              return ListTile(
                                leading: preset != null
                                    ? Icon(preset.icon, color: preset.color)
                                    : const Icon(Icons.notifications_off),
                                title: Text(
                                  '${_formatDateTime(d.start)} - ${_formatDateTime(d.end)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(preset?.name ?? d.presetId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    await ScheduledDndStorage.delete(d.id);
                                    setState(() {});
                                  },
                                ),
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

Future<void> _showAddDnd(
  BuildContext ctx,
  List<StatusPreset> presets,
  VoidCallback onChanged,
) async {
  DateTime start = DateTime.now();
  DateTime end = start.add(const Duration(hours: 8));
  String? presetId = presets.isNotEmpty ? presets.first.id : null;

  final result = await showDialog<bool>(
    context: ctx,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('添加免打扰时段'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('开始'),
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
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
                        );
                        if (t != null) setState(() => start = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('结束'),
                    subtitle: Text(_formatDateTime(end)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: end,
                        firstDate: start,
                        lastDate: DateTime.now().add(const Duration(days: 31)),
                      );
                      if (d != null) {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: end.hour, minute: end.minute),
                        );
                        if (t != null) setState(() => end = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                      }
                    },
                  ),
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
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(
                onPressed: presetId == null
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('添加'),
              ),
            ],
          );
        },
      );
    },
  );

  final pid = presetId;
  if (result == true && pid != null && pid.isNotEmpty) {
    final dnd = ScheduledDnd(
      id: 'dnd_${DateTime.now().millisecondsSinceEpoch}',
      start: start,
      end: end,
      presetId: pid,
    );
    await ScheduledDndStorage.save(dnd);
    onChanged();
  }
}
