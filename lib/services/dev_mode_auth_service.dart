import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// 进入开发者模式前的身份验证：生物识别（指纹/人脸）或设备 PIN/图案。
/// 若设备不支持则跳过验证。
class DevModeAuthService {
  DevModeAuthService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// 设备是否支持本地认证（生物识别或设备凭证）
  static Future<bool> get isSupported async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// 执行验证。返回 true 表示通过或跳过（设备不支持）；false 表示用户取消或失败。
  /// [reason] 展示给用户的验证原因。
  /// 支持时使用生物识别或设备 PIN/图案；不支持时跳过，仅限机主可进入开发者模式。
  static Future<bool> authenticate({String reason = '验证身份以进入开发者模式'}) async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        if (kDebugMode) {
          debugPrint('DevModeAuth: 设备不支持本地认证，跳过验证');
        }
        return true;
      }

      final success = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return success;
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('DevModeAuth: 验证异常 $e');
      }
      return false;
    }
  }
}
