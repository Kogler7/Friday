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

  /// 从 JSON 解析
  static List<StatusPreset> importFromJson(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final list = map['presets'] as List<dynamic>? ?? [];
      return list
          .map((e) => StatusPreset.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<String?> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}
