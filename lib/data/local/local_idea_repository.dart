import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/idea_repository.dart';
import '../../models/idea/chat_message.dart';
import '../../models/idea/idea_session.dart';
import 'legacy_readonly_guard.dart';

class LocalIdeaRepository implements IdeaRepository {
  static const String _keySessionsV2 =
      '${LegacyReadOnlyGuard.v2Prefix}idea_sessions';
  static const String _keyCurrentIdV2 =
      '${LegacyReadOnlyGuard.v2Prefix}idea_current_id';
  static const String _keySessionsLegacy = 'friday_idea_sessions';
  static const String _keyCurrentIdLegacy = 'friday_idea_current_id';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Map<String, IdeaSession> _loadAllSessionsMapV2() {
    final jsonStr = _prefs.getString(_keySessionsV2);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(k, IdeaSession.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAllSessionsMapV2(Map<String, IdeaSession> map) async {
    final encoded = map.map((k, v) => MapEntry(k, v.toJson()));
    await _prefs.setString(_keySessionsV2, jsonEncode(encoded));
  }

  Map<String, IdeaSession> _legacyMap() {
    final jsonStr = _prefs.getString(_keySessionsLegacy);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(k, IdeaSession.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  Map<String, IdeaSession> exportAllSessions() {
    final v2 = _loadAllSessionsMapV2();
    if (v2.isNotEmpty) return v2;
    return _legacyMap();
  }

  Future<Map<String, IdeaSession>> _loadWritableMap() async {
    final v2 = _loadAllSessionsMapV2();
    if (v2.isNotEmpty) return v2;
    final legacy = _legacyMap();
    if (legacy.isNotEmpty) {
      await _saveAllSessionsMapV2(legacy);
    }
    return legacy;
  }

  @override
  List<IdeaSession> getAllSessions({bool includeHidden = false}) {
    final v2 = _loadAllSessionsMapV2();
    var list = (v2.isNotEmpty ? v2.values : _legacyMap().values).toList();
    if (!includeHidden) {
      list = list.where((s) => !s.isHidden).toList();
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  String? getCurrentSessionId() {
    final id = _prefs.getString(_keyCurrentIdV2);
    return id ?? _prefs.getString(_keyCurrentIdLegacy);
  }

  @override
  Future<void> ensureCurrentSessionVisible() async {
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

  @override
  Future<void> setCurrentSessionId(String? id) async {
    if (id == null) {
      await _prefs.remove(_keyCurrentIdV2);
      return;
    }
    await _prefs.setString(_keyCurrentIdV2, id);
  }

  @override
  IdeaSession? getSession(String id) {
    final v2 = _loadAllSessionsMapV2();
    if (v2.isNotEmpty) return v2[id];
    return _legacyMap()[id];
  }

  @override
  Future<IdeaSession> createSession() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final session = IdeaSession(
      id: id,
      title: '未命名会话',
      createdAt: now,
      updatedAt: now,
      messages: const [],
      isLocked: false,
      isHidden: false,
    );
    final map = await _loadWritableMap();
    map[session.id] = session;
    await _saveAllSessionsMapV2(map);
    return session;
  }

  @override
  Future<IdeaSession> createSessionWithFirstMessage(
    String firstMessageContent,
  ) async {
    final trimmed = firstMessageContent.trim();
    final title = trimmed.isEmpty
        ? '未命名会话'
        : (trimmed.length <= 8 ? trimmed : trimmed.substring(0, 8));
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final msg = ChatMessage(
      id: now.millisecondsSinceEpoch.toString(),
      createdAt: now,
      content: firstMessageContent,
    );
    final session = IdeaSession(
      id: id,
      title: title,
      createdAt: now,
      updatedAt: now,
      messages: [msg],
      isLocked: false,
      isHidden: false,
    );
    final map = await _loadWritableMap();
    map[session.id] = session;
    await _saveAllSessionsMapV2(map);
    return session;
  }

  @override
  Future<void> saveSession(IdeaSession session) async {
    final map = await _loadWritableMap();
    map[session.id] = session;
    await _saveAllSessionsMapV2(map);
  }

  @override
  Future<void> deleteSession(String id) async {
    final map = await _loadWritableMap();
    map.remove(id);
    await _saveAllSessionsMapV2(map);
    final current = getCurrentSessionId();
    if (current == id) {
      final visible = getAllSessions(includeHidden: false);
      await setCurrentSessionId(visible.isNotEmpty ? visible.first.id : null);
    }
  }

  @override
  String sessionTitle(IdeaSession session) {
    if (session.messages.isEmpty) return session.title;
    final first = session.messages.first.content.trim();
    if (first.isEmpty) return '未命名会话';
    return first.length > 20 ? '${first.substring(0, 20)}…' : first;
  }

  @override
  ChatMessage? findMessage(String sessionId, String messageId) {
    final session = getSession(sessionId);
    if (session == null) return null;
    for (final message in session.messages) {
      if (message.id == messageId) return message;
    }
    return null;
  }
}
