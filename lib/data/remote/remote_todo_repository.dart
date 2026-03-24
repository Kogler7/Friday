import '../../domain/repositories/todo_repository.dart';
import '../../models/event/todo_item.dart';
import 'in_memory_cache.dart';

class RemoteTodoRepository implements TodoRepository {
  RemoteTodoRepository(this._cache);

  final InMemoryCache _cache;

  @override
  List<TodoItem> getTodos() {
    final list = List<TodoItem>.from(_cache.todos);
    list.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  @override
  Future<TodoItem> addTodo(
    String title, {
    DateTime? dueDate,
    DateTime? reminderAt,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
  }) async {
    final item = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      completed: false,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      reminderAt: reminderAt,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
    );
    await addTodoItem(item);
    return item;
  }

  @override
  Future<void> addTodoItem(TodoItem item) async {
    _cache.todos = [item, ..._cache.todos];
  }

  @override
  Future<void> toggleTodo(String id) async {
    final idx = _cache.todos.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _cache.todos[idx] = _cache.todos[idx].copyWith(
      completed: !_cache.todos[idx].completed,
    );
  }

  @override
  Future<void> updateTodo(String id, String title) async {
    final idx = _cache.todos.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _cache.todos[idx] = _cache.todos[idx].copyWith(title: title.trim());
  }

  @override
  Future<void> updateTodoItem(TodoItem item) async {
    final idx = _cache.todos.indexWhere((e) => e.id == item.id);
    if (idx < 0) return;
    _cache.todos[idx] = item;
  }

  @override
  Future<void> deleteTodo(String id) async {
    _cache.todos = _cache.todos.where((e) => e.id != id).toList();
  }
}
