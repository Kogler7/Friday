import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// 认证结果：成功、跳过（设备未配置/不支持）、失败（用户取消或验证失败）
enum LocalAuthResult {
  success,
  skipped,
  failed,
}

/// 本地身份验证：生物识别（指纹/人脸）或设备 PIN/图案。
/// 若设备不支持或未配置则跳过验证。
class LocalAuthService {
  LocalAuthService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// 设备是否支持本地认证（生物识别或设备凭证）
  static Future<bool> get isSupported async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// 执行验证。返回 [LocalAuthResult]：成功、跳过、失败。
  /// [reason] 展示给用户的验证原因。
  /// 支持且已配置时弹出生物识别/PIN 界面；不支持或未配置时跳过。
  static Future<LocalAuthResult> authenticate({
    String reason = '验证身份',
  }) async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        if (kDebugMode) {
          debugPrint('LocalAuth: 设备不支持本地认证，跳过验证');
        }
        return LocalAuthResult.skipped;
      }

      final success = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return success ? LocalAuthResult.success : LocalAuthResult.failed;
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('LocalAuth: 验证异常 $e');
      }
      final msg = e.toString().toLowerCase();
      if (msg.contains('notavailable') ||
          msg.contains('passcode') ||
          msg.contains('lock') ||
          msg.contains('enrolled') ||
          msg.contains('no biometric')) {
        return LocalAuthResult.skipped;
      }
      return LocalAuthResult.failed;
    }
  }
}
