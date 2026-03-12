import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'offline_sync_service.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionChangeController = StreamController<bool>.broadcast();
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Stream<bool> get connectionStream => _connectionChangeController.stream;

  Future<void> init() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);
    
    _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // connectivity_plus 6.0+ returns a list
    final bool previousStatus = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);
    
    if (previousStatus != _isOnline) {
      _connectionChangeController.add(_isOnline);
      debugPrint('Connectivity Changed: \${_isOnline ? "ONLINE" : "OFFLINE"}');
      
      if (_isOnline) {
        // Trigger sync when reconnected
        const OfflineSyncService().checkAndSync();
      }
    }
  }

  void dispose() {
    _connectionChangeController.close();
  }
}
