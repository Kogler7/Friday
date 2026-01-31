import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/activity_state.dart';
import '../models/hourly_record.dart';
import '../services/hourly_prompt_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';

void _saveIntervalAndCancel(DateTime intervalStart, ActivityState state) {
  final intervalMin = SettingsService.isInitialized
      ? SettingsService.current.reminderIntervalMinutes
      : 60;
  if (kDebugMode) {
    StorageService.saveRecord(
      HourlyRecord(hourStart: intervalStart, state: state),
    );
    NotificationService.cancelForSlot(intervalStart);
    return;
  }
  StorageService.saveRecordsForInterval(
    intervalStart,
    Duration(minutes: intervalMin),
    state,
  );
  NotificationService.cancelForSlot(intervalStart);
}

/// 每小时/每时段弹出的状态选择对话框。
/// [hourStart] 为要记录的时段开始时间（正式：整点如 14:00；开发：2 分钟槽如 14:30）。
/// [onTimeout] 超时未选择时回调，默认会写入「休息」。
/// [timeoutMinutes] 超时分钟数，开发模式建议传 1，正式默认 10。
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
  HourlyPromptService.markDialogShowing();
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _HourlyPromptDialog(
      hourStart: slot,
      timeoutMinutes: timeout,
      onSelected: (state) {
        _saveIntervalAndCancel(slot, state);
        HourlyPromptService.markDialogClosed();
        Navigator.of(ctx).pop();
      },
      onTimeout: () {
        final defaultState = SettingsService.isInitialized
            ? SettingsService.current.quietPeriodDefaultState
            : ActivityState.resting;
        _saveIntervalAndCancel(slot, defaultState);
        HourlyPromptService.markDialogClosed();
        if (ctx.mounted) Navigator.of(ctx).pop();
        onTimeout?.call();
      },
    ),
  ).then((_) => HourlyPromptService.markDialogClosed());
}

class _HourlyPromptDialog extends StatefulWidget {
  final DateTime hourStart;
  final int timeoutMinutes;
  final void Function(ActivityState state) onSelected;
  final VoidCallback onTimeout;

  const _HourlyPromptDialog({
    required this.hourStart,
    required this.timeoutMinutes,
    required this.onSelected,
    required this.onTimeout,
  });

  @override
  State<_HourlyPromptDialog> createState() => _HourlyPromptDialogState();
}

class _HourlyPromptDialogState extends State<_HourlyPromptDialog> {
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

  @override
  Widget build(BuildContext context) {
    final h = widget.hourStart.hour;
    final m = widget.hourStart.minute;
    String pad(int n) => n < 10 ? '0$n' : '$n';
    final hourLabel = m == 0
        ? '${pad(h)}:00 - ${pad((h + 1) % 24)}:00'
        : '${pad(h)}:${pad(m)} - ${pad((h + (m + 2) ~/ 60) % 24)}:${pad((m + 2) % 60)}';
    return AlertDialog(
      title: const Text('过去一小时你在做什么？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('时间段：$hourLabel', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(
            '未选择将在 $_timeText 后自动记为「休息」'
                '${kDebugMode ? '（开发模式超时较短）' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _OptionButton(
                label: ActivityState.working.displayName,
                icon: Icons.work,
                color: Colors.blue,
                onTap: () => widget.onSelected(ActivityState.working),
              ),
              _OptionButton(
                label: ActivityState.resting.displayName,
                icon: Icons.bedtime,
                color: Colors.orange,
                onTap: () => widget.onSelected(ActivityState.resting),
              ),
              _OptionButton(
                label: ActivityState.entertainment.displayName,
                icon: Icons.games,
                color: Colors.green,
                onTap: () => widget.onSelected(ActivityState.entertainment),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(fontSize: 12, color: color)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
