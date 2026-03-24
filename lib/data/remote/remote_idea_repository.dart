import '../../domain/repositories/idea_repository.dart';
import '../../models/idea/chat_message.dart';
import '../../models/idea/idea_session.dart';
import 'in_memory_cache.dart';

class RemoteIdeaRepository implements IdeaRepository {
  RemoteIdeaRepository(this._cache);

  final InMemoryCache _cache;

  @override
  List<IdeaSession> getAllSessions({bool includeHidden = false}) {
    var list = _cache.ideaSessions.values.toList();
    if (!includeHidden) {
      list = list.where((s) => !s.isHidden).toList();
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  String? getCurrentSessionId() => _cache.currentIdeaSessionId;

  @override
  Future<void> ensureCurrentSessionVisible() async {
    final id = _cache.currentIdeaSessionId;
    if (id == null) return;
    final session = _cache.ideaSessions[id];
    if (session == null || !session.isHidden) return;
    final visible = getAllSessions(includeHidden: false);
    _cache.currentIdeaSessionId = visible.isNotEmpty ? visible.first.id : null;
  }

  @override
  Future<void> setCurrentSessionId(String? id) async {
    _cache.currentIdeaSessionId = id;
  }

  @override
  IdeaSession? getSession(String id) => _cache.ideaSessions[id];

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
    _cache.ideaSessions[id] = session;
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
    _cache.ideaSessions[id] = session;
    return session;
  }

  @override
  Future<void> saveSession(IdeaSession session) async {
    _cache.ideaSessions[session.id] = session;
  }

  @override
  Future<void> deleteSession(String id) async {
    _cache.ideaSessions.remove(id);
    if (_cache.currentIdeaSessionId == id) {
      final visible = getAllSessions(includeHidden: false);
      _cache.currentIdeaSessionId = visible.isNotEmpty
          ? visible.first.id
          : null;
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
    final session = _cache.ideaSessions[sessionId];
    if (session == null) return null;
    for (final message in session.messages) {
      if (message.id == messageId) return message;
    }
    return null;
  }
}
