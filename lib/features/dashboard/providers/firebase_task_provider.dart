import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/task_model.dart';

class FirebaseTaskProvider extends ChangeNotifier {
  FirebaseTaskProvider({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  bool _isLoading = false;
  String? _errorMessage;
  List<TaskModel> _tasks = <TaskModel>[];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<TaskModel> get tasks => _tasks;

  Future<void> loadFirebaseTasks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final User? user = _firebaseAuth.currentUser;
      if (user == null) {
        _errorMessage = 'You must be logged in to view synced tasks.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .get();

      _tasks = snapshot.docs
          .map((QueryDocumentSnapshot doc) => _taskFromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      _errorMessage = 'Failed to load synced tasks: ${e.message}';
    } catch (e) {
      _errorMessage = 'Unexpected error loading synced tasks.';
    }

    _isLoading = false;
    notifyListeners();
  }

  TaskModel _taskFromFirestore(QueryDocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TaskModel.fromFirestoreMap(data, doc.id);
  }
}
