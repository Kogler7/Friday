import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 系统通知服务：高优先级渠道，前台/后台均弹窗；整点定时 + 即时推送；点击打开应用并弹出问卷。
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'planplus_hourly';
  static const String _channelName = '小时状态提醒';

  /// 点击通知后待处理的小时（由 HomeScreen 读取并弹窗）
  static DateTime? pendingHourToRecord;

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onSelectNotification,
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse?.payload != null) {
      try {
        pendingHourToRecord = DateTime.parse(launch!.notificationResponse!.payload!);
      } catch (_) {}
    }

    await _createChannel();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  static Future<void> _createChannel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: '每小时提醒填写上一小时状态',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static void _onSelectNotification(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      pendingHourToRecord = DateTime.parse(payload);
    } catch (_) {}
  }

  /// 立即显示一条「上一小时状态」通知（前台也会弹系统横幅，类似微信）
  static Future<void> showHourlyPrompt(DateTime hourToRecord) async {
    if (!_initialized) return;
    final normalized = DateTime(
      hourToRecord.year,
      hourToRecord.month,
      hourToRecord.day,
      hourToRecord.hour,
    );
    final h = normalized.hour;
    final next = (h + 1) % 24;
    String pad(int n) => n < 10 ? '0$n' : '$n';
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '每小时提醒填写上一小时状态',
        importance: Importance.high,
        priority: Priority.high,
        ticker: '过去一小时你在做什么？',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
    final id = normalized.millisecondsSinceEpoch ~/ 1000 % 0x7FFFFFFF;
    await _plugin.show(
      id: id,
      title: '过去一小时你在做什么？',
      body: '${pad(h)}:00 - ${pad(next)}:00 请选择：工作 / 休息 / 娱乐',
      notificationDetails: details,
      payload: normalized.toIso8601String(),
    );
  }

  /// 安排接下来 24 个整点的定时通知（后台到点也会由系统弹出）。
  /// 每次调用前会 [cancelAll]，因此不会因多次重启而堆积。
  static Future<void> scheduleHourlyPrompts() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    final now = DateTime.now();
    final local = tz.TZDateTime.from(now, tz.local);
    String pad(int n) => n < 10 ? '0$n' : '$n';
    for (int i = 0; i < 24; i++) {
      final totalHours = local.hour + 1 + i;
      final dayOffset = totalHours ~/ 24;
      final hour = totalHours % 24;
      final scheduled = tz.TZDateTime(
        local.location,
        local.year,
        local.month,
        local.day + dayOffset,
        hour,
        0,
        0,
      );
      final prev = scheduled.subtract(const Duration(hours: 1));
      final hourToRecord = DateTime(
        prev.year,
        prev.month,
        prev.day,
        prev.hour,
      );
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '每小时提醒填写上一小时状态',
          importance: Importance.high,
          priority: Priority.high,
          ticker: '过去一小时你在做什么？',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      );
      await _plugin.zonedSchedule(
        id: 1000 + i,
        title: '过去一小时你在做什么？',
        body: '${pad(hourToRecord.hour)}:00 请选择：工作 / 休息 / 娱乐',
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: hourToRecord.toIso8601String(),
      );
    }
  }

  /// 清除「待处理小时」（HomeScreen 弹窗后调用）
  static void clearPendingHour() {
    pendingHourToRecord = null;
  }
}
