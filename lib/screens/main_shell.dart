import 'package:flutter/material.dart';

import '../constants/app_config.dart';
import '../services/local_auth_service.dart';
import '../services/hourly_prompt_service.dart';
import '../services/notification_service.dart';
import '../widgets/hourly_prompt_dialog.dart';
import 'about_screen.dart';
import 'event/event_screen.dart';
import 'idea/idea_screen.dart';
import 'idea/session_history_drawer.dart';
import 'settings_screen.dart';
import 'smart/smart_screen.dart';
import 'status/status_screen.dart';
import 'stats/stats_screen.dart';

/// 底部导航：事件、状态、智能(中)、想法、统计；侧边栏 Drawer：头像、设置、关于
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  List<Widget>? _eventAppBarActions;
  List<Widget>? _statusAppBarActions;
  IdeaDrawerProps? _ideaDrawerProps;
  List<Widget>? _ideaAppBarActions;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<_NavItem> _items = [
    _NavItem(label: '日程', icon: Icons.event_note),
    _NavItem(label: '想法', icon: Icons.lightbulb_outline),
    _NavItem(label: '智能', icon: Icons.mic),
    _NavItem(label: '状态', icon: Icons.pie_chart_outline),
    _NavItem(label: '统计', icon: Icons.analytics_outlined),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      EventScreen(
        onAppBarActionsReady: (actions) {
          if (mounted) setState(() => _eventAppBarActions = actions);
        },
      ),
      IdeaScreen(
        onSessionDrawerPropsReady: (p) {
          if (mounted) setState(() => _ideaDrawerProps = p);
        },
        onAppBarActionsReady: (actions) {
          if (mounted) setState(() => _ideaAppBarActions = actions);
        },
        onOpenSessionHistory: () => _scaffoldKey.currentState?.openEndDrawer(),
      ),
      const SmartScreen(),
      StatusScreen(
        onAppBarActionsReady: (actions) {
          if (mounted) setState(() => _statusAppBarActions = actions);
        },
      ),
      const StatsScreen(),
    ];
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

  void _onAboutTap() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => AboutScreen(onDevModeTriggerRequest: _handleDevModeEntry),
      ),
    );
  }

  Future<void> _handleDevModeEntry() async {
    final result = await LocalAuthService.authenticate(
      reason: '验证身份以进入开发者模式',
    );
    if (!mounted) return;
    if (result == LocalAuthResult.success) {
      enterUserDeveloperMode();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已进入开发者模式')),
      );
    } else if (result == LocalAuthResult.skipped) {
      enterUserDeveloperMode();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设备未配置生物识别/锁屏，已跳过验证进入开发者模式'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('验证未通过。请确保设备已录入指纹/人脸或已设置锁屏密码。'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const int smartIndex = 2;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_items[_currentIndex].label),
        backgroundColor: colorScheme.inversePrimary,
        actions: _currentIndex == 0
            ? (_eventAppBarActions ?? [])
            : _currentIndex == 1
                ? (_ideaAppBarActions ?? [])
                : (_currentIndex == 3 ? (_statusAppBarActions ?? []) : null),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: '菜单',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person_outline,
                        size: 48,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'PlanPlus',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '任务与状态规划',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Card(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text('设置'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('关于'),
                        onTap: _onAboutTap,
                        onLongPress: kIsDevMode
                            ? () async {
                                Navigator.pop(context);
                                await _handleDevModeEntry();
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      endDrawer: _currentIndex == 1 && _ideaDrawerProps != null
          ? SessionHistoryDrawer(
              currentSessionId: _ideaDrawerProps!.currentSessionId,
              isDevMode: _ideaDrawerProps!.isDevMode,
              onSessionSelected: _ideaDrawerProps!.onSessionSelected,
              onNewSession: _ideaDrawerProps!.onNewSession,
              onSessionsChanged: _ideaDrawerProps!.onSessionsChanged,
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomAppBar(
        height: 64,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 0, colorScheme),
            _buildNavItem(context, 1, colorScheme),
            _buildCenterSmartButton(context, colorScheme, smartIndex),
            _buildNavItem(context, 3, colorScheme),
            _buildNavItem(context, 4, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    ColorScheme colorScheme,
  ) {
    final item = _items[index];
    final selected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? _selectedIcon(item.icon) : item.icon,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _selectedIcon(IconData outline) {
    if (outline == Icons.lightbulb_outline) return Icons.lightbulb;
    if (outline == Icons.pie_chart_outline) return Icons.pie_chart;
    if (outline == Icons.event_note) return Icons.event;
    if (outline == Icons.analytics_outlined) return Icons.analytics;
    return outline;
  }

  Widget _buildCenterSmartButton(
    BuildContext context,
    ColorScheme colorScheme,
    int smartIndex,
  ) {
    final selected = _currentIndex == smartIndex;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.primary,
          elevation: 4,
          shadowColor: colorScheme.primary.withValues(alpha: 0.5),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => setState(() => _currentIndex = smartIndex),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.mic,
                size: 28,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem({required this.label, required this.icon});
}
