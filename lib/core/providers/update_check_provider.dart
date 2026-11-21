import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../services/update_check_service.dart';
import '../sync/connectivity_service.dart';
import 'app_version_provider.dart';

/// Test injection seam for http.Client.
final updateCheckClientProvider = Provider<http.Client?>((ref) => null);

/// Injected service provider.
final updateCheckServiceProvider = Provider<UpdateCheckService>((ref) {
  final client = ref.watch(updateCheckClientProvider);
  return UpdateCheckService(client: client);
});

class UpdateCheckState {
  final bool isChecking;
  final UpdateManifest? manifest;
  final bool isUpdateAvailable;
  final bool isDismissed;
  final String? installedVersion;
  final String? error;

  const UpdateCheckState({
    this.isChecking = false,
    this.manifest,
    this.isUpdateAvailable = false,
    this.isDismissed = false,
    this.installedVersion,
    this.error,
  });

  UpdateCheckState copyWith({
    bool? isChecking,
    UpdateManifest? manifest,
    bool? isUpdateAvailable,
    bool? isDismissed,
    String? installedVersion,
    String? error,
  }) {
    return UpdateCheckState(
      isChecking: isChecking ?? this.isChecking,
      manifest: manifest ?? this.manifest,
      isUpdateAvailable: isUpdateAvailable ?? this.isUpdateAvailable,
      isDismissed: isDismissed ?? this.isDismissed,
      installedVersion: installedVersion ?? this.installedVersion,
      error: error ?? this.error,
    );
  }
}

class UpdateCheckNotifier extends StateNotifier<UpdateCheckState> {
  final Ref _ref;

  UpdateCheckNotifier(this._ref) : super(const UpdateCheckState());

  /// Checks for updates against the manifest feed.
  /// When [manual] is true, ignores previous dismissal and refreshes state.
  Future<UpdateManifest?> checkForUpdates({bool manual = false}) async {
    state = state.copyWith(isChecking: true, error: null);

    try {
      final service = _ref.read(updateCheckServiceProvider);

      // Guard: Ailyan's edition clients must never receive public clean updates.
      if (service.isAilyansEdition) {
        final installed = await _ref.read(appVersionProvider.future);
        state = state.copyWith(
          isChecking: false,
          isUpdateAvailable: false,
          installedVersion: installed,
        );
        return null;
      }

      // Check connectivity
      ConnectivityResult? conn;
      try {
        final connSvc = _ref.read(connectivityServiceProvider);
        conn = await connSvc.checkCurrent();
      } catch (_) {}

      final manifest = await service.fetchLatestManifest(connectivity: conn);
      final installed = await _ref.read(appVersionProvider.future);

      if (manifest == null) {
        state = state.copyWith(
          isChecking: false,
          installedVersion: installed,
        );
        return null;
      }

      final compareTag = manifest.tag.isNotEmpty ? manifest.tag : manifest.version;
      final isNewer = UpdateCheckService.isNewerVersion(compareTag, installed);
      final isDismissed = manual ? false : await service.isTagDismissed(manifest.tag);

      state = UpdateCheckState(
        isChecking: false,
        manifest: manifest,
        isUpdateAvailable: isNewer,
        isDismissed: isDismissed,
        installedVersion: installed,
      );

      return manifest;
    } catch (e) {
      state = state.copyWith(isChecking: false, error: e.toString());
      return null;
    }
  }

  /// Dismisses the active update banner and saves the dismissed tag in SharedPreferences.
  Future<void> dismissCurrentUpdate() async {
    final manifest = state.manifest;
    if (manifest != null && manifest.tag.isNotEmpty) {
      final service = _ref.read(updateCheckServiceProvider);
      await service.dismissTag(manifest.tag);
    }
    state = state.copyWith(isDismissed: true);
  }
}

final updateCheckProvider =
    StateNotifierProvider<UpdateCheckNotifier, UpdateCheckState>((ref) {
  return UpdateCheckNotifier(ref);
});
