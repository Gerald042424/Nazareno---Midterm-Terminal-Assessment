import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/task_model.dart';
import '../utils/app_constants.dart';
import '../utils/app_result.dart';
import 'sqlite_service.dart';

class SyncService {
  SyncService({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    required SqliteService sqliteService,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth,
       _sqliteService = sqliteService;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final SqliteService _sqliteService;

  Future<AppResult<int>> syncDraftTasksToFirestore() async {
    try {
      final User? user = _firebaseAuth.currentUser;
      if (user == null) {
        return AppResult.failure<int>(
          const AppError(
            message: 'You must be logged in to sync.',
            type: AppErrorType.authentication,
          ),
        );
      }

      final AppResult<List<TaskModel>> localTasksResult = await _sqliteService
          .getAllTasksForSync(user.uid);
      if (!localTasksResult.isSuccess) {
        return AppResult.failure<int>(localTasksResult.error!);
      }

      int syncedCount = 0;
      final List<TaskModel> localTasks = localTasksResult.data ?? <TaskModel>[];
      for (final TaskModel task in localTasks) {
        final int? taskId = task.id;
        if (taskId == null) {
          continue;
        }

        final String cloudId =
            task.cloudId ?? _generateCloudId(user.uid, taskId, task.createdAt);
        if (task.cloudId == null) {
          await _sqliteService.updateTaskCloudId(
            taskId: taskId,
            userId: user.uid,
            cloudId: cloudId,
          );
        }

        final bool isDraft = task.status == AppConstants.taskStatusDraft;
        final TaskModel taskForCloud = task.copyWith(
          cloudId: cloudId,
          userId: user.uid,
          status: isDraft ? AppConstants.taskStatusSynced : task.status,
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('tasks')
            .doc(cloudId)
            .set(
              taskForCloud.toFirestoreMap(user.uid),
              SetOptions(merge: true),
            );

        if (isDraft) {
          await _sqliteService.markTaskSynced(taskId, user.uid);
          syncedCount++;
        }
      }

      return AppResult.success<int>(syncedCount);
    } on FirebaseException catch (_) {
      return AppResult.failure<int>(
        const AppError(
          message: 'Cloud sync failed. Please try again.',
          type: AppErrorType.firestore,
        ),
      );
    } catch (_) {
      return AppResult.failure<int>(
        const AppError(
          message: 'Unexpected sync error.',
          type: AppErrorType.unknown,
        ),
      );
    }
  }

  Future<AppResult<void>> deleteTaskFromFirestore(int taskId) async {
    try {
      final User? user = _firebaseAuth.currentUser;
      if (user == null) {
        return AppResult.failure<void>(
          const AppError(
            message: 'You must be logged in to delete.',
            type: AppErrorType.authentication,
          ),
        );
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .where('id', isEqualTo: taskId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.delete();
      }

      return AppResult.success<void>(null);
    } on FirebaseException catch (_) {
      return AppResult.failure<void>(
        const AppError(
          message: 'Cloud delete failed. Please try again.',
          type: AppErrorType.firestore,
        ),
      );
    } catch (_) {
      return AppResult.failure<void>(
        const AppError(
          message: 'Unexpected delete error.',
          type: AppErrorType.unknown,
        ),
      );
    }
  }

  Future<AppResult<int>> restoreCloudTasksToLocal() async {
    try {
      final User? user = _firebaseAuth.currentUser;
      if (user == null) {
        return AppResult.failure<int>(
          const AppError(
            message: 'You must be logged in to restore tasks.',
            type: AppErrorType.authentication,
          ),
        );
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .get();

      final List<TaskModel> cloudTasks = snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
        final Map<String, dynamic> data = doc.data();
        TaskModel task = TaskModel.fromFirestoreMap(
          data,
          doc.id,
        ).copyWith(userId: user.uid);

        // Backward compatibility:
        // Old cloud docs did not store cloudId and may still have draft status
        // even if they were previously treated as synced locally.
        final String? rawCloudId = data['cloudId'] as String?;
        final bool isLegacyDocWithoutCloudId =
            rawCloudId == null || rawCloudId.isEmpty;
        if (isLegacyDocWithoutCloudId &&
            task.status == AppConstants.taskStatusDraft) {
          task = task.copyWith(status: AppConstants.taskStatusSynced);
        }

        return task;
      }).toList();

      final AppResult<void> upsertResult = await _sqliteService
          .upsertTasksFromCloud(userId: user.uid, tasks: cloudTasks);
      if (!upsertResult.isSuccess) {
        return AppResult.failure<int>(upsertResult.error!);
      }

      return AppResult.success<int>(cloudTasks.length);
    } on FirebaseException catch (_) {
      return AppResult.failure<int>(
        const AppError(
          message: 'Cloud restore failed. Please try again.',
          type: AppErrorType.firestore,
        ),
      );
    } catch (_) {
      return AppResult.failure<int>(
        const AppError(
          message: 'Unexpected restore error.',
          type: AppErrorType.unknown,
        ),
      );
    }
  }

  String _generateCloudId(String userId, int localId, DateTime createdAt) {
    return '${userId}_${createdAt.microsecondsSinceEpoch}_$localId';
  }
}
