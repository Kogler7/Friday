import 'package:flutter/material.dart';

import '../../models/status/status_preset.dart';
import '../../services/status_preset_storage.dart';
import '../../services/storage_service.dart';

/// 批量设置：将指定日期时间范围内的记录全部改为某预设
void showBatchSetSheet(BuildContext context, VoidCallback onComplete) {
  DateTime dateStart = DateTime.now();
  DateTime dateEnd = DateTime.now();
  TimeOfDay timeStart = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay timeEnd = const TimeOfDay(hour: 23, minute: 59);
  StatusPreset? selectedPreset = StatusPresetStorage.getAll().firstOrNull;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final presets = StatusPresetStorage.getAll();
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '批量设置',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '将选定日期时间范围内的记录全部改为指定预设',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    title: const Text('开始日期'),
                    subtitle: Text(
                      '${dateStart.year}-${dateStart.month.toString().padLeft(2, '0')}-${dateStart.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: dateStart,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (p != null) setState(() => dateStart = p);
                    },
                  ),
                  ListTile(
                    title: const Text('结束日期'),
                    subtitle: Text(
                      '${dateEnd.year}-${dateEnd.month.toString().padLeft(2, '0')}-${dateEnd.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: dateEnd,
                        firstDate: dateStart,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (p != null) setState(() => dateEnd = p);
                    },
                  ),
                  ListTile(
                    title: const Text('开始时间'),
                    subtitle: Text(
                      '${timeStart.hour.toString().padLeft(2, '0')}:${timeStart.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final p = await showTimePicker(
                        context: ctx,
                        initialTime: timeStart,
                      );
                      if (p != null) setState(() => timeStart = p);
                    },
                  ),
                  ListTile(
                    title: const Text('结束时间'),
                    subtitle: Text(
                      '${timeEnd.hour.toString().padLeft(2, '0')}:${timeEnd.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final p = await showTimePicker(
                        context: ctx,
                        initialTime: timeEnd,
                      );
                      if (p != null) setState(() => timeEnd = p);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '预设',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<StatusPreset>(
                    value: selectedPreset,
                    items: presets
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Row(
                                children: [
                                  Icon(p.icon, size: 20, color: p.color),
                                  const SizedBox(width: 8),
                                  Text(p.name),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => selectedPreset = v),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: selectedPreset == null || dateEnd.isBefore(dateStart)
                        ? null
                          : () {
                            final preset = selectedPreset!;
                            final ds = dateStart;
                            final de = dateEnd;
                            final ts = timeStart;
                            final te = timeEnd;
                            final parentContext = context;
                            Navigator.of(ctx).pop();
                            WidgetsBinding.instance.addPostFrameCallback((_) async {
                              await StorageService.saveRecordsForBatch(
                                dateStart: ds,
                                dateEnd: de,
                                timeStart: ts,
                                timeEnd: te,
                                data: preset.data.copyWith(presetId: preset.id),
                              );
                              onComplete();
                              if (parentContext.mounted) {
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  const SnackBar(content: Text('批量设置完成')),
                                );
                              }
                            });
                          },
                    child: const Text('应用'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
