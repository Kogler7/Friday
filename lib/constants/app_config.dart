import 'dart:async';

import 'package:flutter/foundation.dart';

/// 用户可手动开启的开发者模式；退出时机由 [devModeExitTiming] 决定
final ValueNotifier<bool> userDeveloperMode = ValueNotifier<bool>(false);

/// 开发者模式退出时机（用户已选择时非 null；null 表示默认「切后台退出」且尚未选择）
enum DevModeExitTiming {
  /// 切回后台时退出（默认）
  onBackground,
  /// 定时后退出（由定时器触发）
  afterDelay,
  /// 直到用户主动退出或再次触发切换
  untilExit,
}

final ValueNotifier<DevModeExitTiming?> devModeExitTiming =
    ValueNotifier<DevModeExitTiming?>(null);

Timer? _devModeExitTimer;

void cancelDevModeExitTimer() {
  _devModeExitTimer?.cancel();
  _devModeExitTimer = null;
}

/// 在 [duration] 后退出开发者模式
void startDevModeExitTimer(Duration duration) {
  cancelDevModeExitTimer();
  _devModeExitTimer = Timer(duration, () {
    cancelDevModeExitTimer();
    exitUserDeveloperMode();
  });
}

void enterUserDeveloperMode() {
  cancelDevModeExitTimer();
  devModeExitTiming.value = null;
  userDeveloperMode.value = true;
}

void exitUserDeveloperMode() {
  cancelDevModeExitTimer();
  devModeExitTiming.value = null;
  userDeveloperMode.value = false;
}

/// 是否应在切后台时退出开发者模式（null 或 onBackground 为是；untilExit / afterDelay 为否）
bool get shouldExitDevModeOnBackground {
  final t = devModeExitTiming.value;
  return t == null || t == DevModeExitTiming.onBackground;
}
