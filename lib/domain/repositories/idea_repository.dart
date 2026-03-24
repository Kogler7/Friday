import '../../models/idea/chat_message.dart';
import '../../models/idea/idea_session.dart';

abstract class IdeaRepository {
  List<IdeaSession> getAllSessions({bool includeHidden = false});

  String? getCurrentSessionId();

  Future<void> ensureCurrentSessionVisible();

  Future<void> setCurrentSessionId(String? id);

  IdeaSession? getSession(String id);

  Future<IdeaSession> createSession();

  Future<IdeaSession> createSessionWithFirstMessage(String firstMessageContent);

  Future<void> saveSession(IdeaSession session);

  Future<void> deleteSession(String id);

  String sessionTitle(IdeaSession session);

  ChatMessage? findMessage(String sessionId, String messageId);
}
