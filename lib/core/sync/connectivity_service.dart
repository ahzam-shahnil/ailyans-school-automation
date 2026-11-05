import 'dart:async';
import 'dart:io';

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

  /// Supabase URL from dart-define, or null when unconfigured (tests).
  static String? _supabaseUrl() {
    const url = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    return url.isEmpty ? null : url;
  }

  /// Probes actual reachability because macOS can report an interface as up
  /// while there is no internet route.
  Future<bool> _isReachable() async {
    final url = _supabaseUrl();
    if (url == null) {
      // No URL configured (unit tests). Treat as reachable.
      return true;
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    try {
      final uri = Uri.parse(url);
      final request =
          await client.headUrl(uri).timeout(const Duration(seconds: 3));
      final response =
          await request.close().timeout(const Duration(seconds: 3));
      // 200-499 means the endpoint answered (401 on the bare URL is still up).
      return response.statusCode < 500;
    } catch (_) {
      // Timeout, DNS failure, connection refused -> offline.
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Broadcast stream of connectivity results. Emits on any change.
  Stream<ConnectivityResult> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.asyncMap((results) async {
      final pluginResult = _normalize(results);
      if (pluginResult == ConnectivityResult.none) return pluginResult;
      final reachable = await _isReachable();
      return reachable ? pluginResult : ConnectivityResult.none;
    });
  }

  Future<ConnectivityResult> checkCurrent() async {
    final results = await _connectivity.checkConnectivity();
    final pluginResult = _normalize(results);
    if (pluginResult == ConnectivityResult.none) return pluginResult;
    final reachable = await _isReachable();
    return reachable ? pluginResult : ConnectivityResult.none;
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);
