import '../../models/event/todo_item.dart';

abstract class TodoRepository {
  List<TodoItem> getTodos();

  Future<TodoItem> addTodo(
    String title, {
    DateTime? dueDate,
    DateTime? reminderAt,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
  });

  Future<void> addTodoItem(TodoItem item);

  Future<void> toggleTodo(String id);

  Future<void> updateTodo(String id, String title);

  Future<void> updateTodoItem(TodoItem item);

  Future<void> deleteTodo(String id);
}
