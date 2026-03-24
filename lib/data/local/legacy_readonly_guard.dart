/// 仅用于标识“旧数据源只读”的约束。
/// 新链路写入必须使用 v2 key，禁止写回 legacy key。
class LegacyReadOnlyGuard {
  LegacyReadOnlyGuard._();

  static const String v2Prefix = 'friday_v2_';
}
