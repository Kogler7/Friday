import 'package:flutter/foundation.dart';

/// 用户可手动开启的开发者模式（切后台或重启后自动退出）
final ValueNotifier<bool> userDeveloperMode = ValueNotifier<bool>(false);

void enterUserDeveloperMode() {
  userDeveloperMode.value = true;
}

void exitUserDeveloperMode() {
  userDeveloperMode.value = false;
}
