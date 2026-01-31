import 'package:flutter/foundation.dart';

/// 是否为开发/调试模式（Release 构建恒为 false，不会预约 24 条定时通知）
bool get kIsDevMode => kDebugMode;

/// 用户通过「连续点击五次关于」进入的开发者模式（切后台或重启后自动退出）
final ValueNotifier<bool> userDeveloperMode = ValueNotifier<bool>(false);

void enterUserDeveloperMode() {
  userDeveloperMode.value = true;
}

void exitUserDeveloperMode() {
  userDeveloperMode.value = false;
}
