import 'package:flutter/material.dart';

/// 开发者模式退出时机选项
enum DevModeExitOption {
  /// 立刻退出
  immediate,
  /// 切回后台时退出
  onBackground,
  /// 定时后退出
  afterDelay,
  /// 直到退出 App
  untilExit,
}

/// 底部弹框：选择开发者模式退出时机（立刻 / 切回后台 / 定时后 / 直到退出）
class DevModeExitTimingSheet extends StatelessWidget {
  const DevModeExitTimingSheet({
    super.key,
    required this.onSelected,
  });

  final void Function(DevModeExitOption option, [Duration? delay]) onSelected;

  static const List<({String label, String subtitle, DevModeExitOption option})> _options = [
    (label: '立刻退出', subtitle: '立即退出开发者模式', option: DevModeExitOption.immediate),
    (label: '切回后台', subtitle: '切换到后台时自动退出', option: DevModeExitOption.onBackground),
    (label: '定时后退出', subtitle: '选择时长，到时后自动退出', option: DevModeExitOption.afterDelay),
    (label: '直到退出', subtitle: '保持开发者模式直到再次触发或退出 App', option: DevModeExitOption.untilExit),
  ];

  static const List<({String label, Duration duration})> _durations = [
    (label: '5 分钟', duration: Duration(minutes: 5)),
    (label: '10 分钟', duration: Duration(minutes: 10)),
    (label: '15 分钟', duration: Duration(minutes: 15)),
    (label: '30 分钟', duration: Duration(minutes: 30)),
    (label: '1 小时', duration: Duration(hours: 1)),
  ];

  Future<void> _pickDuration(BuildContext context) async {
    final theme = Theme.of(context);
    final chosen = await showModalBottomSheet<Duration>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                '选择退出时间',
                style: theme.textTheme.titleMedium,
              ),
            ),
            ..._durations.map((d) => ListTile(
                  title: Text(d.label),
                  onTap: () => Navigator.pop(ctx, d.duration),
                )),
          ],
        ),
      ),
    );
    if (chosen != null && context.mounted) {
      Navigator.pop(context);
      onSelected(DevModeExitOption.afterDelay, chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '开发者模式退出时机',
              style: theme.textTheme.titleMedium,
            ),
          ),
          ..._options.map((o) {
            if (o.option == DevModeExitOption.afterDelay) {
              return ListTile(
                leading: Icon(_iconFor(o.option), color: colorScheme.primary),
                title: Text(o.label),
                subtitle: Text(o.subtitle),
                onTap: () => _pickDuration(context),
              );
            }
            return ListTile(
              leading: Icon(_iconFor(o.option), color: colorScheme.primary),
              title: Text(o.label),
              subtitle: Text(o.subtitle),
              onTap: () {
                Navigator.pop(context);
                onSelected(o.option);
              },
            );
          }),
        ],
      ),
    );
  }

  IconData _iconFor(DevModeExitOption option) {
    switch (option) {
      case DevModeExitOption.immediate:
        return Icons.exit_to_app;
      case DevModeExitOption.onBackground:
        return Icons.phone_android;
      case DevModeExitOption.afterDelay:
        return Icons.timer_outlined;
      case DevModeExitOption.untilExit:
        return Icons.all_inclusive;
    }
  }
}
