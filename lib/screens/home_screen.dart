import 'package:flutter/material.dart';

import '../constants/app_config.dart';
import '../services/hourly_prompt_service.dart';
import '../services/notification_service.dart';
import '../widgets/hourly_prompt_dialog.dart';
import 'settings_screen.dart';

/// 主页：独立设计，目前为头像 + 设置入口；整点提醒仍在此注册。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    HourlyPromptService.setShowPrompt((hourToRecord) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showHourlyPromptDialog(context, hourStart: hourToRecord);
      });
    });
    HourlyPromptService.start();
    _checkNotificationLaunch();
  }

  void _checkNotificationLaunch() {
    final hour = NotificationService.pendingHourToRecord;
    if (hour == null || !mounted) return;
    NotificationService.clearPendingHour();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHourlyPromptDialog(context, hourStart: hour);
    });
  }

  @override
  void dispose() {
    HourlyPromptService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('主页'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          if (kIsDevMode)
            IconButton(
              icon: const Icon(Icons.science),
              tooltip: '开发',
              onPressed: () {},
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 头像占位，后续可扩展为真实头像/个人信息
              CircleAvatar(
                radius: 48,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.person_outline,
                  size: 56,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'PlanPlus',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '任务与状态规划',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings_outlined, size: 20),
                label: const Text('设置'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
