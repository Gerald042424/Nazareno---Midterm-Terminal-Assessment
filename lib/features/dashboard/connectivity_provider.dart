import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/connectivity_service.dart';

class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider(this._connectivityService);

  final ConnectivityService _connectivityService;
  StreamSubscription<bool>? _connectivitySub;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    _isOnline = await _connectivityService.isOnline();
    notifyListeners();
    _connectivitySub ??=
        _connectivityService.onOnlineStatusChanged.listen((bool isOnline) {
      _isOnline = isOnline;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
