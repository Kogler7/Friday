import 'package:flutter/foundation.dart';

/// Debug 模式下数据源切换：用户真实数据 vs 内置测试数据
/// 两种数据使用不同存储 key 前缀，互不影响
class StatusDataSource {
  StatusDataSource._();

  static const String _prefixProd = 'planplus_';
  static const String _prefixDebugTest = 'planplus_debug_test_';

  static final ValueNotifier<bool> useTestData = ValueNotifier<bool>(false);

  static void toggleTestData() {
    useTestData.value = !useTestData.value;
  }

  /// 是否使用测试数据（仅 debug 模式有效）
  static bool get isTestData => kDebugMode && useTestData.value;

  static String get _prefix => isTestData ? _prefixDebugTest : _prefixProd;

  static String key(String base) => _prefix + base;
}
