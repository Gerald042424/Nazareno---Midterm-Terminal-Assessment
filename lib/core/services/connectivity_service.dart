import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  Stream<bool> get onOnlineStatusChanged {
    return _connectivity.onConnectivityChanged.map(_isOnlineFromResults);
  }

  Future<bool> isOnline() async {
    final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    return _isOnlineFromResults(results);
  }

  bool _isOnlineFromResults(List<ConnectivityResult> results) {
    return !results.contains(ConnectivityResult.none);
  }
}
