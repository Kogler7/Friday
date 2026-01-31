import 'package:flutter/foundation.dart';

/// 是否为开发/调试模式（Release 构建恒为 false，不会预约 24 条定时通知）
bool get kIsDevMode => kDebugMode;
