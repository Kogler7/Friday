import '../../models/activity/hourly_record.dart';
import '../../models/event/todo_item.dart';
import '../../models/idea/idea_session.dart';

class InMemoryCache {
  Map<String, IdeaSession> ideaSessions = {};
  String? currentIdeaSessionId;
  List<TodoItem> todos = [];
  Map<String, List<HourlyRecord>> statusByDate = {};

  DateTime? lastSyncedAt;
  String? boundChannelId;

  bool get isEmpty =>
      ideaSessions.isEmpty && todos.isEmpty && statusByDate.isEmpty;

  void clearAll() {
    ideaSessions = {};
    currentIdeaSessionId = null;
    todos = [];
    statusByDate = {};
    lastSyncedAt = null;
    boundChannelId = null;
  }
}
