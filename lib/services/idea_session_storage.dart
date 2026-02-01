import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/idea/chat_message.dart';
import '../models/idea/idea_session.dart';
import 'chat_storage_service.dart';

const String _keySessions = 'planplus_idea_sessions';
const String _keyCurrentId = 'planplus_idea_current_id';

/// 多会话存储：会话列表、当前会话、迁移旧单会话数据
class IdeaSessionStorage {
  IdeaSessionStorage._();
  static late final SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateFromLegacyChat();
  }

  /// 若存在旧版单会话数据且尚无会话，则迁移为一条默认会话
  static Future<void> _migrateFromLegacyChat() async {
    final sessionsJson = _prefs.getString(_keySessions);
    if (sessionsJson != null && sessionsJson.isNotEmpty) return;
    final legacy = ChatStorageService.getMessages();
    if (legacy.isEmpty) {
      final first = await createSession();
      await setCurrentSessionId(first.id);
      return;
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = IdeaSession(
      id: id,
      title: _sessionTitleFromMessages(legacy),
      createdAt: legacy.first.createdAt,
      updatedAt: legacy.last.createdAt,
      messages: List.from(legacy),
      isLocked: false,
      isHidden: false,
    );
    await _saveSession(session);
    await setCurrentSessionId(id);
  }

  static String _sessionTitleFromMessages(List<ChatMessage> messages) {
    if (messages.isEmpty) return '未命名会话';
    final first = messages.first.content.trim();
    if (first.isEmpty) return '未命名会话';
    return first.length > 20 ? '${first.substring(0, 20)}…' : first;
  }

  static Map<String, IdeaSession> _loadAllSessionsMap() {
    final jsonStr = _prefs.getString(_keySessions);
    if (jsonStr == null) return {};
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return map.map((k, v) =>
        MapEntry(k, IdeaSession.fromJson(v as Map<String, dynamic>)));
  }

  static Future<void> _saveAllSessions(Map<String, IdeaSession> map) async {
    final encoded = map.map((k, v) => MapEntry(k, v.toJson()));
    await _prefs.setString(_keySessions, jsonEncode(encoded));
  }

  static Future<void> _saveSession(IdeaSession session) async {
    final map = _loadAllSessionsMap();
    map[session.id] = session;
    await _saveAllSessions(map);
  }

  /// 获取所有会话（按更新时间倒序）。[includeHidden] 为 true 时包含已隐藏会话（开发者模式用）
  static List<IdeaSession> getAllSessions({bool includeHidden = false}) {
    final map = _loadAllSessionsMap();
    var list = map.values.toList();
    if (!includeHidden) list = list.where((s) => !s.isHidden).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  static String? getCurrentSessionId() {
    return _prefs.getString(_keyCurrentId);
  }

  /// 若当前会话为隐藏状态，则切换到第一个未隐藏会话，无则清空当前会话（退出开发者模式时调用）
  static Future<void> ensureCurrentSessionVisible() async {
    final id = getCurrentSessionId();
    if (id == null) return;
    final session = getSession(id);
    if (session == null || !session.isHidden) return;
    final visible = getAllSessions(includeHidden: false);
    if (visible.isEmpty) {
      await setCurrentSessionId(null);
    } else {
      await setCurrentSessionId(visible.first.id);
    }
  }

  static Future<void> setCurrentSessionId(String? id) async {
    if (id == null) {
      await _prefs.remove(_keyCurrentId);
    } else {
      await _prefs.setString(_keyCurrentId, id);
    }
  }

  static IdeaSession? getSession(String id) {
    return _loadAllSessionsMap()[id];
  }

  /// 创建新会话并保存
  static Future<IdeaSession> createSession() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final session = IdeaSession(
      id: id,
      title: '未命名会话',
      createdAt: now,
      updatedAt: now,
      messages: [],
      isLocked: false,
      isHidden: false,
    );
    await _saveSession(session);
    return session;
  }

  /// 更新会话（如标题、消息、锁定、隐藏）
  static Future<void> saveSession(IdeaSession session) async {
    await _saveSession(session);
  }

  /// 彻底删除会话
  static Future<void> deleteSession(String id) async {
    final map = _loadAllSessionsMap();
    map.remove(id);
    await _saveAllSessions(map);
    final current = getCurrentSessionId();
    if (current == id) {
      final remaining = map.values.toList();
      if (remaining.isNotEmpty) {
        remaining.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        await setCurrentSessionId(remaining.first.id);
      } else {
        await setCurrentSessionId(null);
      }
    }
  }

  /// 更新会话标题（取首条消息摘要）
  static String sessionTitle(IdeaSession session) {
    if (session.messages.isEmpty) return session.title;
    return _sessionTitleFromMessages(session.messages);
  }
}
