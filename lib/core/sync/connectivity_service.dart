import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phase F-5: wraps connectivity_plus as an injectable service for tests.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// Collapse connectivity_plus 6.x's List into a single "best" result.
  static ConnectivityResult _normalize(List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityResult.none;
    if (results.every((r) => r == ConnectivityResult.none)) {
      return ConnectivityResult.none;
    }
    return results.firstWhere((r) => r != ConnectivityResult.none);
  }

  /// Broadcast stream of connectivity results. Emits on any change.
  Stream<ConnectivityResult> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_normalize);
  }

  Future<ConnectivityResult> checkCurrent() async {
    final results = await _connectivity.checkConnectivity();
    return _normalize(results);
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);
