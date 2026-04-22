import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  SyncProvider(this._syncService);

  final SyncService _syncService;
  static const String _lastSyncField = 'lastSyncTime';

  bool _isSyncing = false;
  String? _errorMessage;
  String? _successMessage;
  DateTime? _lastSyncTime;
  String? _userId;

  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  DateTime? get lastSyncTime => _lastSyncTime;

  Future<void> init(String? userId) async {
    _userId = userId;
    if (userId == null) {
      return;
    }

    try {
      final DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        final dynamic lastSyncMillis = doc.get(_lastSyncField);
        if (lastSyncMillis is int) {
          _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
        }
      }
    } catch (_) {
      // Fall back to null on error
    }
  }

  Future<void> _saveLastSyncTime() async {
    if (_userId == null || _lastSyncTime == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .set({
        _lastSyncField: _lastSyncTime!.millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (_) {
      // Silently fail
    }
  }

  Future<bool> sync() async {
    _isSyncing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final result = await _syncService.syncDraftTasksToFirestore();
    if (result.isSuccess) {
      final int count = result.data ?? 0;
      _successMessage = count == 0 ? 'No draft tasks to sync.' : 'Synced $count task(s).';
      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();
      _isSyncing = false;
      notifyListeners();
      return true;
    }

    _errorMessage = result.error?.message;
    _isSyncing = false;
    notifyListeners();
    return false;
  }
}
