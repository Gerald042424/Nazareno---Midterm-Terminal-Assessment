import 'package:sqflite/sqflite.dart';

import '../models/task_model.dart';
import '../utils/app_constants.dart';
import '../utils/app_result.dart';

class SqliteService {
  static const String _databaseName = 'fastrm.db';
  static const int _databaseVersion = 2;
  static const String _tasksTable = 'tasks';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final String dbPath = await getDatabasesPath();
    _database = await openDatabase(
      '$dbPath/$_databaseName',
      version: _databaseVersion,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tasksTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cloudId TEXT,
            userId TEXT,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            status TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_tasksTable ADD COLUMN cloudId TEXT');
          await db.execute('ALTER TABLE $_tasksTable ADD COLUMN userId TEXT');
        }
      },
    );

    return _database!;
  }

  Future<AppResult<TaskModel>> createTask({
    required String userId,
    required String title,
    required String description,
  }) async {
    try {
      final Database db = await database;
      final TaskModel draft = TaskModel(
        userId: userId,
        title: title,
        description: description,
        status: AppConstants.taskStatusDraft,
        createdAt: DateTime.now(),
      );

      final int insertedId = await db.insert(
        _tasksTable,
        draft.toSqliteMap()..remove('id'),
      );

      return AppResult.success<TaskModel>(draft.copyWith(id: insertedId));
    } catch (_) {
      return AppResult.failure<TaskModel>(
        const AppError(
          message: 'Failed to save task locally.',
          type: AppErrorType.database,
        ),
      );
    }
  }

  Future<AppResult<List<TaskModel>>> getTasks(String userId) async {
    try {
      final Database db = await database;
      await _claimLegacyTasksForUser(db, userId);
      final List<Map<String, dynamic>> rows = await db.query(
        _tasksTable,
        where: 'userId = ?',
        whereArgs: <String>[userId],
        orderBy: 'createdAt DESC',
      );
      final List<TaskModel> tasks = rows.map(TaskModel.fromSqliteMap).toList();
      return AppResult.success<List<TaskModel>>(tasks);
    } catch (_) {
      return AppResult.failure<List<TaskModel>>(
        const AppError(
          message: 'Failed to load local tasks.',
          type: AppErrorType.database,
        ),
      );
    }
  }

  Future<AppResult<List<TaskModel>>> getDraftTasks(String userId) async {
    try {
      final Database db = await database;
      await _claimLegacyTasksForUser(db, userId);
      final List<Map<String, dynamic>> rows = await db.query(
        _tasksTable,
        where: 'userId = ? AND status = ?',
        whereArgs: <String>[userId, AppConstants.taskStatusDraft],
      );
      final List<TaskModel> tasks = rows.map(TaskModel.fromSqliteMap).toList();
      return AppResult.success<List<TaskModel>>(tasks);
    } catch (_) {
      return AppResult.failure<List<TaskModel>>(
        const AppError(
          message: 'Failed to load draft tasks.',
          type: AppErrorType.database,
        ),
      );
    }
  }

  Future<AppResult<void>> markTaskSynced(int taskId, String userId) async {
    try {
      final Database db = await database;
      await db.update(
        _tasksTable,
        <String, Object>{'status': AppConstants.taskStatusSynced},
        where: 'id = ? AND userId = ?',
        whereArgs: <Object>[taskId, userId],
      );
      return AppResult.success<void>(null);
    } catch (_) {
      return AppResult.failure<void>(
        const AppError(
          message: 'Failed to update task status.',
          type: AppErrorType.database,
        ),
      );
    }
  }

  Future<AppResult<void>> updateTaskCloudId({
    required int taskId,
    required String userId,
    required String cloudId,
  }) async {
    try {
      final Database db = await database;
      await db.update(
        _tasksTable,
        <String, Object>{'cloudId': cloudId, 'userId': userId},
        where: 'id = ? AND userId = ?',
        whereArgs: <Object>[taskId, userId],
      );
      return AppResult.success<void>(null);
    } catch (_) {
      return AppResult.failure<void>(
        const AppError(
          message: 'Failed to update task cloud id.',
          type: AppErrorType.database,
        ),
      );
    }
  }

  Future<AppResult<void>> upsertTaskFromCloud({
    required String userId,
    required TaskModel task,
  }) async {
    try {
      final Database db = await database;
      final TaskModel normalizedTask = task.copyWith(userId: userId);
      final Map<String, dynamic> map = normalizedTask.toSqliteMap()
        ..remove('id');
      final String? cloudId = normalizedTask.cloudId;

      if (cloudId == null || cloudId.isEmpty) {
        return AppResult.failure<void>(
          const AppError(
            message: 'Invalid cloud task id.',
            type: AppErrorType.validation,
          ),
        );
      }

      final List<Map<String, dynamic>> existing = await db.query(
        _tasksTable,
        where: 'cloudId = ? AND userId = ?',
        whereArgs: <String>[cloudId, userId],
        limit: 1,
      );

      if (existing.isEmpty) {
        await db.insert(_tasksTable, map);
      } else {
        final TaskModel existingTask = TaskModel.fromSqliteMap(existing.first);
        final bool shouldPreserveSyncedStatus =
            existingTask.status == AppConstants.taskStatusSynced &&
            normalizedTask.status == AppConstants.taskStatusDraft;
        if (shouldPreserveSyncedStatus) {
          map['status'] = AppConstants.taskStatusSynced;
        }

        await db.update(
          _tasksTable,
          map,
          where: 'cloudId = ? AND userId = ?',
          whereArgs: <String>[cloudId, userId],
        );
      }

      return AppResult.success<void>(null);
    } catch (_) {
      return AppResult.failure<void>(
        const AppError(
          message: 'Failed to restore task from cloud.',
          type: AppErrorType.database,
        ),
      );
    }
  }

  Future<AppResult<void>> upsertTasksFromCloud({
    required String userId,
    required List<TaskModel> tasks,
  }) async {
    try {
      for (final TaskModel task in tasks) {
        final result = await upsertTaskFromCloud(userId: userId, task: task);
        if (!result.isSuccess) {
          return result;
        }
      }
      return AppResult.success<void>(null);
    } catch (_) {
      return AppResult.failure<void>(
        const AppError(
          message: 'Failed to restore cloud tasks.',
          type: AppErrorType.database,
        ),
      );
    }
  }

  Future<AppResult<List<TaskModel>>> getAllTasksForSync(String userId) async {
    try {
      final Database db = await database;
      await _claimLegacyTasksForUser(db, userId);
      final List<Map<String, dynamic>> rows = await db.query(
        _tasksTable,
        where: 'userId = ?',
        whereArgs: <String>[userId],
        orderBy: 'createdAt DESC',
      );
      final List<TaskModel> tasks = rows
          .map(TaskModel.fromSqliteMap)
          .map((TaskModel task) => task.copyWith(userId: userId))
          .toList();
      return AppResult.success<List<TaskModel>>(tasks);
    } catch (_) {
      return AppResult.failure<List<TaskModel>>(
        const AppError(
          message: 'Failed to load tasks for sync.',
          type: AppErrorType.database,
        ),
      );
    }
  }

  Future<AppResult<void>> deleteTask(int id, String userId) async {
    try {
      final Database db = await database;
      await db.delete(
        _tasksTable,
        where: 'id = ? AND userId = ?',
        whereArgs: <Object>[id, userId],
      );
      return AppResult.success<void>(null);
    } catch (_) {
      return AppResult.failure<void>(
        const AppError(
          message: 'Failed to delete task.',
          type: AppErrorType.database,
        ),
      );
    }
  }

  Future<void> _claimLegacyTasksForUser(Database db, String userId) async {
    await db.update(_tasksTable, <String, Object>{
      'userId': userId,
    }, where: 'userId IS NULL');

    await db.rawUpdate(
      'UPDATE $_tasksTable SET cloudId = CAST(id AS TEXT) WHERE userId = ? AND cloudId IS NULL',
      <Object>[userId],
    );
  }
}
