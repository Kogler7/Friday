import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/activity/hourly_record.dart';
import '../models/status/status_preset.dart';
import '../models/status/status_record_data.dart';
import '../screens/status/status_record_form_sheet.dart';
import '../services/hourly_prompt_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/status_recommendation_service.dart';
import '../services/storage_service.dart';
import 'preset_picker_sheet.dart';

void _saveIntervalAndCancel(DateTime intervalStart, StatusRecordData data) {
  final intervalMin = SettingsService.isInitialized
      ? SettingsService.current.reminderIntervalMinutes
      : 60;
  if (kDebugMode) {
    StorageService.saveRecord(HourlyRecord(hourStart: intervalStart, data: data));
    NotificationService.cancelForSlot(intervalStart);
    return;
  }
  StorageService.saveRecordsForInterval(
    intervalStart,
    Duration(minutes: intervalMin),
    data,
  );
  NotificationService.cancelForSlot(intervalStart);
}

/// 每小时/每时段弹出的状态选择对话框。
void showHourlyPromptDialog(
  BuildContext context, {
  required DateTime hourStart,
  VoidCallback? onTimeout,
  int? timeoutMinutes,
}) {
  final slot = DateTime(
    hourStart.year,
    hourStart.month,
    hourStart.day,
    hourStart.hour,
    hourStart.minute,
    0,
    0,
  );
  final timeout = timeoutMinutes ?? (kDebugMode ? 1 : 10);
  final recommendation = StatusRecommendationService.getRecommendation(slot);
  HourlyPromptService.markDialogShowing();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    builder: (ctx) => _HourlyPromptSheet(
      hourStart: slot,
      timeoutMinutes: timeout,
      recommendation: recommendation,
      onSelected: (data) {
        _saveIntervalAndCancel(slot, data);
        HourlyPromptService.markDialogClosed();
        Navigator.of(ctx).pop();
      },
      onTimeout: () {
        _saveIntervalAndCancel(slot, recommendation.preset.data.copyWith(presetId: recommendation.preset.id));
        HourlyPromptService.markDialogClosed();
        if (ctx.mounted) Navigator.of(ctx).pop();
        onTimeout?.call();
      },
    ),
  ).then((_) => HourlyPromptService.markDialogClosed());
}

class _HourlyPromptSheet extends StatefulWidget {
  final DateTime hourStart;
  final int timeoutMinutes;
  final RecommendationResult recommendation;
  final void Function(StatusRecordData data) onSelected;
  final VoidCallback onTimeout;

  const _HourlyPromptSheet({
    required this.hourStart,
    required this.timeoutMinutes,
    required this.recommendation,
    required this.onSelected,
    required this.onTimeout,
  });

  @override
  State<_HourlyPromptSheet> createState() => _HourlyPromptSheetState();
}

class _HourlyPromptSheetState extends State<_HourlyPromptSheet> {
  late int _remainingSeconds;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeoutMinutes * 60;
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || _timedOut) return false;
      setState(() {
        if (_remainingSeconds <= 1) {
          _timedOut = true;
          widget.onTimeout();
          return;
        }
        _remainingSeconds--;
      });
      return true;
    });
  }

  String get _timeText {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    String pad(int n) => n < 10 ? '0$n' : '$n';
    return '${pad(m)}:${pad(s)}';
  }

  void _openDetailForm() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatusRecordFormSheet(
        initialData: const StatusRecordData(),
        onSubmit: (data) {
          Navigator.of(ctx).pop();
          widget.onSelected(data);
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _openPresetPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => PresetPickerSheet(
        recommendedPreset: widget.recommendation.preset,
        recommendedProbability: widget.recommendation.sampleCount > 0
            ? widget.recommendation.probability
            : null,
        onSelect: widget.onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hourStart.hour;
    final m = widget.hourStart.minute;
    String pad(int n) => n < 10 ? '0$n' : '$n';
    final hourLabel = m == 0
        ? '${pad(h)}:00 - ${pad((h + 1) % 24)}:00'
        : '${pad(h)}:${pad(m)} - ${pad((h + (m + 2) ~/ 60) % 24)}:${pad((m + 2) % 60)}';
    final rec = widget.recommendation;

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '过去一小时你在做什么？',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Text('时间段：$hourLabel', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text(
                  '未选择将在 $_timeText 后自动记为「${rec.preset.name}」'
                      '${rec.sampleCount > 0 ? '（推荐 ${(rec.probability * 100).toInt()}%）' : ''}'
                      '${kDebugMode ? '（开发模式超时较短）' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                const SizedBox(height: 16),
                _PresetChip(
                  preset: rec.preset,
                  probability: rec.sampleCount > 0 ? rec.probability : null,
                  onTap: () => widget.onSelected(rec.preset.data.copyWith(presetId: rec.preset.id)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openPresetPicker,
                  icon: const Icon(Icons.expand_more, size: 20),
                  label: const Text('选择更多'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _openDetailForm,
                  icon: const Icon(Icons.edit_note, size: 20),
                  label: const Text('详细填写'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final StatusPreset preset;
  final double? probability;
  final VoidCallback onTap;

  const _PresetChip({
    required this.preset,
    this.probability,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: preset.color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(preset.icon, color: preset.color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      preset.name,
                      style: TextStyle(
                        fontSize: 16,
                        color: preset.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (probability != null && probability! > 0)
                      Text(
                        '推荐 ${(probability! * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: preset.color.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
