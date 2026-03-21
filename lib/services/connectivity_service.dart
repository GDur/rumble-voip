import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  bool _isOnline = true;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityService() {
    _init();
  }

  bool get isOnline => _isOnline;

  Future<void> _init() async {
    // Check initial state
    final results = await _connectivity.checkConnectivity();
    _updateState(results);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateState);
  }

  void _updateState(List<ConnectivityResult> results) {
    // If results contains none, we are offline
    final bool currentlyOnline = !results.contains(ConnectivityResult.none);
    
    if (_isOnline != currentlyOnline) {
      _isOnline = currentlyOnline;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
