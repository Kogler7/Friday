import '../activity/hourly_record.dart';
import '../event/todo_item.dart';
import '../idea/idea_session.dart';

class TransferSnapshot {
  final Map<String, IdeaSession> ideaSessions;
  final String? currentIdeaSessionId;
  final List<TodoItem> todos;
  final Map<String, List<HourlyRecord>> statusByDate;

  const TransferSnapshot({
    required this.ideaSessions,
    required this.currentIdeaSessionId,
    required this.todos,
    required this.statusByDate,
  });

  factory TransferSnapshot.empty() {
    return const TransferSnapshot(
      ideaSessions: {},
      currentIdeaSessionId: null,
      todos: [],
      statusByDate: {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ideaSessions': ideaSessions.map((k, v) => MapEntry(k, v.toJson())),
      'currentIdeaSessionId': currentIdeaSessionId,
      'todos': todos.map((e) => e.toJson()).toList(),
      'statusByDate': statusByDate.map(
        (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
      ),
    };
  }

  factory TransferSnapshot.fromJson(Map<String, dynamic> json) {
    final sessionMap = (json['ideaSessions'] as Map<String, dynamic>? ?? {})
        .map(
          (k, v) =>
              MapEntry(k, IdeaSession.fromJson(v as Map<String, dynamic>)),
        );
    final todos = (json['todos'] as List<dynamic>? ?? [])
        .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final status = <String, List<HourlyRecord>>{};
    final rawStatus = json['statusByDate'] as Map<String, dynamic>? ?? {};
    for (final entry in rawStatus.entries) {
      final list = (entry.value as List<dynamic>? ?? [])
          .map((e) => HourlyRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      status[entry.key] = list;
    }
    return TransferSnapshot(
      ideaSessions: sessionMap,
      currentIdeaSessionId: json['currentIdeaSessionId'] as String?,
      todos: todos,
      statusByDate: status,
    );
  }
}
