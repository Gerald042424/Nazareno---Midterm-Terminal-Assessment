import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/models/task_model.dart';
import '../../core/services/sqlite_service.dart';

class TaskProvider extends ChangeNotifier {
  TaskProvider(this._sqliteService, this._firebaseAuth);

  final SqliteService _sqliteService;
  final FirebaseAuth _firebaseAuth;

  bool _isLoading = false;
  String? _errorMessage;
  List<TaskModel> _tasks = <TaskModel>[];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<TaskModel> get tasks => _tasks;

  String? get _currentUserId => _firebaseAuth.currentUser?.uid;

  Future<void> loadTasks() async {
    final String? userId = _currentUserId;
    if (userId == null) {
      _tasks = <TaskModel>[];
      _errorMessage = 'You must be logged in to load tasks.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _sqliteService.getTasks(userId);
    if (result.isSuccess) {
      _tasks = result.data ?? <TaskModel>[];
    } else {
      _errorMessage = result.error?.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createTask({
    required String title,
    required String description,
  }) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      _errorMessage = 'You must be logged in to create tasks.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    notifyListeners();

    final result = await _sqliteService.createTask(
      userId: userId,
      title: title,
      description: description,
    );

    if (!result.isSuccess) {
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }

    await loadTasks();
    return true;
  }

  Future<bool> deleteTask(int id) async {
    final String? userId = _currentUserId;
    if (userId == null) {
      _errorMessage = 'You must be logged in to delete tasks.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    notifyListeners();

    final result = await _sqliteService.deleteTask(id, userId);

    if (!result.isSuccess) {
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }

    await loadTasks();
    return true;
  }
}
