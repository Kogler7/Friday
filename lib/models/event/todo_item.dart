/// 待办项
class TodoItem {
  final String id;
  final String title;
  final bool completed;
  final DateTime createdAt;
  /// 截止日期（DDL）
  final DateTime? dueDate;
  /// 当天提醒时间
  final DateTime? reminderAt;
  /// 日程开始
  final DateTime? scheduledStart;
  /// 日程结束
  final DateTime? scheduledEnd;

  const TodoItem({
    required this.id,
    required this.title,
    required this.completed,
    required this.createdAt,
    this.dueDate,
    this.reminderAt,
    this.scheduledStart,
    this.scheduledEnd,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'reminderAt': reminderAt?.toIso8601String(),
        'scheduledStart': scheduledStart?.toIso8601String(),
        'scheduledEnd': scheduledEnd?.toIso8601String(),
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      title: json['title'] as String,
      completed: json['completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      reminderAt: json['reminderAt'] != null
          ? DateTime.parse(json['reminderAt'] as String)
          : null,
      scheduledStart: json['scheduledStart'] != null
          ? DateTime.parse(json['scheduledStart'] as String)
          : null,
      scheduledEnd: json['scheduledEnd'] != null
          ? DateTime.parse(json['scheduledEnd'] as String)
          : null,
    );
  }

  TodoItem copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? reminderAt,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      reminderAt: reminderAt ?? this.reminderAt,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
    );
  }
}
