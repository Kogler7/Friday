import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/idea/chat_message.dart';

const String _keyChat = 'friday_chat';

/// 想法记录（自聊）的本地存储
class ChatStorageService {
  ChatStorageService._();
  static late final SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static List<ChatMessage> _load() {
    final jsonStr = _prefs.getString(_keyChat);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _save(List<ChatMessage> messages) async {
    final list = messages.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyChat, jsonEncode(list));
  }

  /// 获取全部消息（按时间正序）
  static List<ChatMessage> getMessages() {
    final list = _load();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// 获取某时间范围内的消息（闭区间，按时间正序）
  static List<ChatMessage> getMessagesInRange(DateTime start, DateTime end) {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    final list = _load();
    return list
        .where((m) =>
            !m.createdAt.isBefore(startDay) && !m.createdAt.isAfter(endDay))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// 添加一条消息
  static Future<ChatMessage> addMessage(String content) async {
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      content: content.trim(),
    );
    final list = _load();
    list.add(msg);
    await _save(list);
    return msg;
  }

  /// 删除一条消息（可选，用于导出后清理等）
  static Future<void> deleteMessage(String id) async {
    final list = _load();
    list.removeWhere((m) => m.id == id);
    await _save(list);
  }
}
