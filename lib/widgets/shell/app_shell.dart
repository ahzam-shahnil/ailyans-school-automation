import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/session_provider.dart';
import '../../core/sync/connectivity_service.dart';
import '../../core/sync/sync_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../screens/login/change_password_dialog.dart';
import 'app_sidebar.dart';
import 'app_status_bar.dart';
import 'app_top_bar.dart';

/// Persistent desktop application shell wrapping all authenticated routes.
class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final FocusNode _searchFocusNode = FocusNode();

  StreamSubscription<ConnectivityResult>? _connectivitySub;
  Timer? _periodicSyncTimer;

  @override
  void initState() {
    super.initState();
    // F-5: bootstrap after the first frame so provider state is never mutated
    // during widget-tree build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrapSync();
    });
  }

  /// Attaches the connectivity listener and 30s periodic sync timer.
  /// All platform calls are guarded so widget tests never fail on
  /// MissingPluginException or pending timers.
  void _bootstrapSync() {
    // connectivity_plus uses platform channels/EventChannels that are not
    // registered in widget tests; skip the real plugin there so existing
    // tests never see MissingPluginException.
    final isTest =
        Platform.environment.containsKey('FLUTTER_TEST') ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) return;

    final svc = ref.read(connectivityServiceProvider);

    try {
      svc
          .checkCurrent()
          .then((result) {
            if (!mounted) return;
            ref.read(syncPushProvider.notifier).updateConnectivity(result);
          })
          .catchError((Object e) {
            debugPrint('[F-5] Initial connectivity check failed: $e');
          });

      _connectivitySub = svc.onConnectivityChanged.listen(
        (result) {
          if (!mounted) return;
          ref.read(syncPushProvider.notifier).updateConnectivity(result);
        },
        onError: (Object e) {
          debugPrint('[F-5] Connectivity stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('[F-5] Connectivity bootstrap failed: $e');
    }

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        ref.read(syncPushProvider.notifier).triggerSync();
      });
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _periodicSyncTimer?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return CallbackShortcuts(
      bindings: {
        // Ctrl+N / Cmd+N -> Contextual new record (Student Registration Wizard)
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          context.go('/students/new');
        },
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
          context.go('/students/new');
        },

        // Ctrl+K / Cmd+K -> Focus global search input
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const AppSidebar(),
                    Expanded(
                      child: Column(
                        children: [
                          AppTopBar(searchFocusNode: _searchFocusNode),
                          if (session?.hasWeakPasswordWarning == true)
                            _buildWeakPasswordBanner(context, ref, session!),
                          Expanded(child: widget.child),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const AppStatusBar(showSyncStatus: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeakPasswordBanner(
    BuildContext context,
    WidgetRef ref,
    UserSession session,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.statusWarningBg,
        border: Border(
          bottom: BorderSide(color: AppColors.statusWarningBorder, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18.0,
            color: AppColors.statusWarningText,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Your password is shorter than the recommended 8 characters. '
              'Update it at your earliest convenience.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusWarningText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ChangePasswordDialog.show(context, username: session.user.name);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.statusWarningText,
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
            ),
            child: Text(
              'Update Password',
              style: AppTypography.label.copyWith(
                color: AppColors.statusWarningText,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18.0),
            color: AppColors.statusWarningText,
            tooltip: 'Dismiss warning',
            onPressed: () {
              ref.read(sessionProvider.notifier).dismissWeakPasswordWarning();
            },
          ),
        ],
      ),
    );
  }
}
