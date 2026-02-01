import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/status/status_preset.dart';

/// 预设导入导出（JSON，支持剪贴板）
class PresetImportExport {
  PresetImportExport._();

  static const String _exportVersion = '1';

  /// 导出为 JSON 字符串
  static String exportToJson(List<StatusPreset> presets) {
    final list = presets.map((p) => p.toJson()).toList();
    return jsonEncode({'version': _exportVersion, 'presets': list});
  }

  /// 格式化 JSON（美化输出）
  static String formatJson(String jsonStr) {
    try {
      final obj = jsonDecode(jsonStr);
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return jsonStr;
    }
  }

  /// 从 JSON 解析，返回 (预设列表, 错误信息)
  static (List<StatusPreset>?, String?) parseFromJson(String jsonStr) {
    if (jsonStr.trim().isEmpty) return (null, '输入为空');
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final list = map['presets'] as List<dynamic>? ?? [];
      final presets = <StatusPreset>[];
      for (var i = 0; i < list.length; i++) {
        try {
          presets.add(
              StatusPreset.fromJson(list[i] as Map<String, dynamic>));
        } catch (e) {
          return (null, '第 ${i + 1} 项解析失败: $e');
        }
      }
      return (presets, null);
    } catch (e) {
      return (null, 'JSON 解析失败: $e');
    }
  }

  /// 从 JSON 解析（兼容旧用法）
  static List<StatusPreset> importFromJson(String jsonStr) {
    final (presets, _) = parseFromJson(jsonStr);
    return presets ?? [];
  }

  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<String?> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}
