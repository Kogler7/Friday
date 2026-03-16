import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_config.dart';
import '../services/local_auth_service.dart';
import '../widgets/dev_mode_exit_timing_sheet.dart';
// 定期问卷已关闭
// import '../services/hourly_prompt_service.dart';
// import '../services/notification_service.dart';
// import '../services/settings_service.dart';
// import '../widgets/hourly_prompt_dialog.dart';
import '../widgets/personal_drawer.dart';
import 'about_screen.dart';
import 'event/event_screen.dart';
import 'focus/focus_screen.dart';
import 'idea/idea_screen.dart';
import 'idea/session_history_drawer.dart';
import 'timeline/timeline_screen.dart';
import 'stats/stats_screen.dart';
import 'instant_ai/instant_ai_screen.dart';

/// 底部导航：日程、想法、时间轴(中)、专注、统计；侧边栏 Drawer：个人、设置、关于
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  List<Widget>? _eventAppBarActions;
  List<Widget>? _timelineAppBarActions;
  IdeaDrawerProps? _ideaDrawerProps;
  List<Widget>? _ideaAppBarActions;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _centerButtonKey = GlobalKey();

  late final AnimationController _timelineExpandController;
  late final CurvedAnimation _timelineExpandCurve;
  /// null: 无遮罩 | expanding: 圆形扩散中 | instant_ai: 显示即时 AI 内容
  String? _timelineOverlayPhase;
  /// 遮罩层中 AI 按钮的位置（布局后更新）
  Rect? _overlayButtonRect;
  Offset? _overlayCircleCenter;
  Timer? _longPressActivateTimer;

  /// 想法页多选：是否处于多选、退出多选的回调（返回键优先退出多选）
  bool _ideaMultiSelectMode = false;
  VoidCallback? _exitIdeaMultiSelect;
  /// 双退保底：第一次返回提示「再按一次退出」，第二次真正退出
  bool _pendingExit = false;
  Timer? _exitBackTimer;

  static const List<_NavItem> _items = [
    _NavItem(label: '日程', icon: Icons.event_note),
    _NavItem(label: '想法', icon: Icons.lightbulb_outline),
    _NavItem(label: '时间轴', icon: Icons.timeline),
    _NavItem(label: '专注', icon: Icons.self_improvement),
    _NavItem(label: '统计', icon: Icons.analytics_outlined),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _timelineExpandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _timelineExpandCurve = CurvedAnimation(
      parent: _timelineExpandController,
      curve: Curves.easeInOutCubic,
    );
    _timelineExpandController.addStatusListener((status) {
        if (status == AnimationStatus.completed && _timelineOverlayPhase == 'expanding') {
          if (!mounted) return;
          setState(() => _timelineOverlayPhase = 'instant_ai');
        }
      });
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
        onMultiSelectStateChange: (isMultiSelect, exitMultiSelect) {
          if (mounted) {
            setState(() {
              _ideaMultiSelectMode = isMultiSelect;
              _exitIdeaMultiSelect = exitMultiSelect;
            });
          }
        },
      ),
      TimelineScreen(
        onAppBarActionsReady: (actions) {
          if (mounted) setState(() => _timelineAppBarActions = actions);
        },
      ),
      const FocusScreen(),
      const StatsScreen(),
    ];
    // 定期问卷与主页弹窗已关闭，需要时再启用
    // HourlyPromptService.setShowPrompt((hourToRecord) {
    //   if (!mounted) return;
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     if (!mounted) return;
    //     showHourlyPromptDialog(context, hourStart: hourToRecord);
    //   });
    // });
    // HourlyPromptService.start();
    // _checkNotificationLaunch();
  }

  // void _checkNotificationLaunch() {
  //   final hour = NotificationService.pendingHourToRecord;
  //   if (hour == null || !mounted) return;
  //   NotificationService.clearPendingHour();
  //   if (!SettingsService.current.hourlyPromptEnabled) return;
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     if (!mounted) return;
  //     showHourlyPromptDialog(context, hourStart: hour);
  //   });
  // }

  @override
  void dispose() {
    _exitBackTimer?.cancel();
    _longPressActivateTimer?.cancel();
    _timelineExpandController.dispose();
    // HourlyPromptService.stop();
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
    final isDevMode = userDeveloperMode.value;

    if (isDevMode) {
      // 已设置过退出时机：再次触发则立刻退出
      if (devModeExitTiming.value != null) {
        exitUserDeveloperMode();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已退出开发者模式')),
        );
        return;
      }
      // 未设置退出时机：弹出选择框
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => DevModeExitTimingSheet(
          onSelected: (option, [duration]) {
            switch (option) {
              case DevModeExitOption.immediate:
                exitUserDeveloperMode();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已退出开发者模式')),
                  );
                }
                break;
              case DevModeExitOption.onBackground:
                devModeExitTiming.value = DevModeExitTiming.onBackground;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('将在切回后台时退出开发者模式')),
                  );
                }
                break;
              case DevModeExitOption.afterDelay:
                if (duration != null) {
                  devModeExitTiming.value = DevModeExitTiming.afterDelay;
                  startDevModeExitTimer(duration);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '将在 ${duration.inMinutes} 分钟后自动退出开发者模式',
                        ),
                      ),
                    );
                  }
                }
                break;
              case DevModeExitOption.untilExit:
                devModeExitTiming.value = DevModeExitTiming.untilExit;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('将保持开发者模式直到再次触发或退出 App'),
                    ),
                  );
                }
                break;
            }
          },
        ),
      );
      return;
    }

    // 普通模式：验证后进入开发者模式
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

  void _updateOverlayButtonPosition() {
    if (!mounted || _timelineOverlayPhase != 'expanding') return;
    final buttonBox = _centerButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null || !buttonBox.hasSize) return;
    final topLeft = buttonBox.localToGlobal(Offset.zero);
    final center = buttonBox.localToGlobal(Offset(buttonBox.size.width / 2, buttonBox.size.height / 2));
    if (mounted) {
      setState(() {
        _overlayButtonRect = Rect.fromLTWH(topLeft.dx, topLeft.dy, buttonBox.size.width, buttonBox.size.height);
        _overlayCircleCenter = center;
      });
    }
  }

  void _closeInstantAiOverlay() {
    if (!mounted) return;
    _timelineExpandController.reset();
    setState(() {
      _timelineOverlayPhase = null;
      _overlayButtonRect = null;
      _overlayCircleCenter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    const int timelineIndex = 2;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool inIdeaMultiSelect = _currentIndex == 1 && _ideaMultiSelectMode;
    return PopScope(
      canPop: _timelineOverlayPhase != 'instant_ai' &&
          !inIdeaMultiSelect &&
          _pendingExit,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_timelineOverlayPhase == 'instant_ai') {
          _closeInstantAiOverlay();
          return;
        }
        if (inIdeaMultiSelect) {
          _exitIdeaMultiSelect?.call();
          return;
        }
        _exitBackTimer?.cancel();
        _pendingExit = true;
        if (mounted) setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('再按一次退出'),
            duration: Duration(seconds: 2),
          ),
        );
        _exitBackTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _pendingExit = false);
          }
        });
      },
      child: Stack(
        children: [
          Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_currentIndex == 1
            ? (_ideaDrawerProps?.sessionTitle ?? _items[1].label)
            : _items[_currentIndex].label),
        backgroundColor: colorScheme.inversePrimary,
        actions: _currentIndex == 0
            ? (_eventAppBarActions ?? [])
            : _currentIndex == 1
                ? (_ideaAppBarActions ?? [])
                : (_currentIndex == 2 ? (_timelineAppBarActions ?? []) : null),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: '菜单',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: PersonalDrawer(
        onAboutTap: _onAboutTap,
        onDevModeEntry: _handleDevModeEntry,
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
            _buildCenterTimelineButton(context, colorScheme, timelineIndex),
            _buildNavItem(context, 3, colorScheme),
            _buildNavItem(context, 4, colorScheme),
          ],
        ),
      ),
    ),
        if (_timelineOverlayPhase != null)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: _timelineOverlayPhase == 'instant_ai'
                  ? InstantAiScreen(onBack: _closeInstantAiOverlay)
                  : _TimelineExpandOverlay(
                      progress: _timelineExpandCurve,
                      colorScheme: colorScheme,
                      circleCenter: _overlayCircleCenter,
                      buttonRect: _overlayButtonRect,
                    ),
            ),
          ),
        ],
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
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
      ),
    );
  }

  IconData _selectedIcon(IconData outline) {
    if (outline == Icons.lightbulb_outline) return Icons.lightbulb;
    if (outline == Icons.self_improvement) return Icons.self_improvement;
    if (outline == Icons.event_note) return Icons.event;
    if (outline == Icons.analytics_outlined) return Icons.analytics;
    if (outline == Icons.timeline) return Icons.timeline;
    return outline;
  }

  void _onTimelinePointerDown(int timelineIndex) {
    _longPressActivateTimer?.cancel();
    _longPressActivateTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _timelineOverlayPhase = 'expanding';
        _overlayButtonRect = null;
        _overlayCircleCenter = null;
      });
      _timelineExpandController.forward();
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateOverlayButtonPosition());
    });
  }

  void _onTimelinePointerUp(int timelineIndex) {
    _longPressActivateTimer?.cancel();
    if (_timelineOverlayPhase != null) {
      if (_timelineOverlayPhase == 'instant_ai') return;
      if (_timelineExpandController.status == AnimationStatus.completed) return;
      _timelineExpandController.reverse().then((_) {
        if (mounted) {
          _timelineExpandController.reset();
          setState(() {
            _timelineOverlayPhase = null;
            _overlayButtonRect = null;
            _overlayCircleCenter = null;
          });
        }
      });
    } else {
      setState(() => _currentIndex = timelineIndex);
    }
  }

  Widget _buildCenterTimelineButton(
    BuildContext context,
    ColorScheme colorScheme,
    int timelineIndex,
  ) {
    final selected = _currentIndex == timelineIndex;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Listener(
          onPointerDown: (_) => _onTimelinePointerDown(timelineIndex),
          onPointerUp: (_) => _onTimelinePointerUp(timelineIndex),
          onPointerCancel: (_) => _onTimelinePointerUp(timelineIndex),
          child: Material(
            key: _centerButtonKey,
            color: selected
                ? colorScheme.primaryContainer
                : colorScheme.primary,
            elevation: 4,
            shadowColor: colorScheme.primary.withValues(alpha: 0.5),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _currentIndex = timelineIndex),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.timeline,
                  size: 28,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineExpandOverlay extends StatelessWidget {
  const _TimelineExpandOverlay({
    required this.progress,
    required this.colorScheme,
    required this.circleCenter,
    required this.buttonRect,
  });

  final Animation<double> progress;
  final ColorScheme colorScheme;
  final Offset? circleCenter;
  final Rect? buttonRect;

  @override
  Widget build(BuildContext context) {
    final rect = buttonRect;
    return IgnorePointer(
      ignoring: true,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: progress,
            builder: (context, child) {
              return CustomPaint(
                painter: _TimelineExpandPainter(
                  progress: progress.value,
                  startColor: colorScheme.primary,
                  endColor: colorScheme.surface,
                  center: circleCenter,
                ),
                size: Size.infinite,
              );
            },
          ),
          if (rect != null)
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: IgnorePointer(
                ignoring: true,
                child: Center(
                  child: Material(
                    color: colorScheme.primary,
                    elevation: 4,
                    shadowColor: colorScheme.primary.withValues(alpha: 0.5),
                    shape: const CircleBorder(),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.auto_awesome,
                        size: 28,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineExpandPainter extends CustomPainter {
  _TimelineExpandPainter({
    required this.progress,
    required this.startColor,
    required this.endColor,
    this.center,
  });

  final double progress;
  final Color startColor;
  final Color endColor;
  final Offset? center;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final c = center ?? Offset(size.width / 2, size.height);
    final maxRadius = math.sqrt(
      math.max(c.dx, size.width - c.dx) * math.max(c.dx, size.width - c.dx) +
      math.max(c.dy, size.height - c.dy) * math.max(c.dy, size.height - c.dy),
    );
    final radius = maxRadius * progress;
    final color = Color.lerp(startColor, endColor, progress)!;
    final opacity = progress.clamp(0.0, 1.0);
    canvas.drawCircle(c, radius, Paint()..color = color.withValues(alpha: opacity));
  }

  @override
  bool shouldRepaint(covariant _TimelineExpandPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.startColor != startColor ||
      oldDelegate.endColor != endColor;
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem({required this.label, required this.icon});
}
