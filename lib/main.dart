import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'constants/app_config.dart';
import 'data/repositories/repository_facade.dart';
import 'screens/main_shell.dart';
import 'services/activity_tag_storage.dart';
import 'services/agent_storage.dart';
import 'services/legacy_auto_migration_service.dart';
import 'services/scheduled_dnd_storage.dart';
import 'services/status_preset_storage.dart';
// import 'services/notification_service.dart'; // 定期问卷已关闭
import 'services/settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 锁定竖屏，避免横屏旋转提示
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const FridayApp());
}

/// 根组件：监听用户开发者模式与生命周期，切后台或重启时退出开发者模式；仅在开发者模式下显示 debug banner。
class FridayApp extends StatefulWidget {
  const FridayApp({super.key});

  @override
  State<FridayApp> createState() => _FridayAppState();
}

class _FridayAppState extends State<FridayApp> with WidgetsBindingObserver {
  bool _userDevMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    userDeveloperMode.addListener(_onUserDevModeChanged);
    SettingsService.currentNotifier.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    userDeveloperMode.removeListener(_onUserDevModeChanged);
    SettingsService.currentNotifier.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onUserDevModeChanged() {
    if (mounted) setState(() => _userDevMode = userDeveloperMode.value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      if (userDeveloperMode.value && shouldExitDevModeOnBackground) {
        exitUserDeveloperMode();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = SettingsService.currentNotifier.value;
    final seedColor = Color(prefs.seedColorValue);
    return MaterialApp(
      title: 'Friday',
      debugShowCheckedModeBanner: _userDevMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: prefs.themeMode,
      home: const _AppLoader(),
    );
  }
}

/// 加载阶段只做 3 个存储初始化，不碰通知；完成后直接进 MainShell，通知在后台延后初始化。
class _AppLoader extends StatefulWidget {
  const _AppLoader();

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      await SettingsService.init();
      await AgentStorage.init();
      await StatusPresetStorage.init();
      await ActivityTagStorage.init();
      await ScheduledDndStorage.init();
      await RepositoryFacade.init();
      await LegacyAutoMigrationService.runIfEnabled();
      if (!mounted) return;
      setState(() => _ready = true);
      // 进入主页后再在后台初始化通知，避免启动阶段卡死
      // 定期问卷通知已关闭，需要时再启用
      // Future.delayed(const Duration(milliseconds: 500), () {
      //   try {
      //     NotificationService.init().then((_) {
      //       if (kDebugMode) {
      //         NotificationService.scheduleDevModePrompts();
      //       } else {
      //         NotificationService.scheduleHourlyPrompts();
      //       }
      //     });
      //   } catch (_) {}
      // });
    } catch (e, st) {
      debugPrint('Friday init error: $e\n$st');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const MainShell();
    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text('初始化失败', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_error!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '加载中…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
