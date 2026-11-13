import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/session_provider.dart';
import '../../core/db/database.dart';
import '../../core/sync/connectivity_service.dart';
import '../../core/sync/sync_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../core/utils/responsive_breakpoints.dart';
import '../../screens/login/change_password_dialog.dart';
import 'app_sidebar.dart';
import 'app_status_bar.dart';
import 'app_top_bar.dart';
import 'mobile_bottom_nav.dart';

/// Persistent desktop application shell wrapping all authenticated routes.
class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  final FocusNode _searchFocusNode = FocusNode();

  /// Collapsed rail width (matches AppSidebar's collapsed AnimatedContainer
  /// width) and the flyout panel width.
  static const double _railWidth = 68.0;
  static const double _flyoutWidth = 250.0;

  StreamSubscription<ConnectivityResult>? _connectivitySub;
  Timer? _periodicSyncTimer;

  // G-10 Shot 10b: polls _sync_outbox every 2s so any local SQLite write is
  // auto-pushed to Supabase within ~1-3s without the user tapping Sync Now
  // (the in-runSync isPushing/isPulling guard acts as the debounce).
  Timer? _outboxWatcherTimer;

  @override
  void initState() {
    super.initState();
    // G-10 Shot 10b: immediate pull from Supabase when the app returns to
    // the foreground, so remote changes made on other devices are visible
    // within seconds of resuming.
    WidgetsBinding.instance.addObserver(this);
    // F-5: bootstrap after the first frame so provider state is never mutated
    // during widget-tree build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrapSync();
    });
  }

  /// Attaches the connectivity listener, the 10s periodic sync timer, and the
  /// 2s outbox auto-push watcher.
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
      // G-10 Shot 10b: 30s -> 10s polling fallback (when Realtime is quiet).
      _periodicSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (!mounted) return;
        ref.read(syncPushProvider.notifier).triggerSync();
      });

      // G-10 Shot 10b: outbox auto-push watcher — local writes land in
      // _sync_outbox via triggers; the moment a row appears, push it.
      _outboxWatcherTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (!mounted) return;
        try {
          final db = await DatabaseService.instance.database;
          final result = await db.rawQuery(
            'SELECT COUNT(*) AS c FROM _sync_outbox',
          );
          final count = (result.first['c'] as int?) ?? 0;
          if (count > 0 && mounted) {
            ref.read(syncPushProvider.notifier).triggerSync();
          }
        } catch (_) {
          // DB not ready yet, skip.
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // G-10 Shot 10b: immediate pull when the app comes back to the
    // foreground (pull-only would miss local pushes, so full sync).
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(syncPushProvider.notifier).triggerSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _periodicSyncTimer?.cancel();
    _outboxWatcherTimer?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final activeFlyoutModule = ref.watch(sidebarFlyoutProvider);

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < ResponsiveBreakpoints.mobileMax) {
              return _buildMobileScaffold(context);
            }

            return Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            const AppSidebar(),
                            Expanded(
                              child: Column(
                                children: [
                                  AppTopBar(searchFocusNode: _searchFocusNode),
                                  if (session?.hasWeakPasswordWarning == true)
                                    _buildWeakPasswordBanner(
                                      context,
                                      ref,
                                      session!,
                                    ),
                                  Expanded(child: widget.child),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Collapsed-rail flyout: scrim and slide-out sub-menu
                        // are mounted ONLY while a module flyout is open, so
                        // closed-state taps elsewhere are never intercepted.
                        if (activeFlyoutModule != null) ...[
                          Positioned(
                            left: _railWidth + _flyoutWidth,
                            top: 0.0,
                            right: 0.0,
                            bottom: 0.0,
                            child: GestureDetector(
                              onTap: () => ref
                                  .read(sidebarFlyoutProvider.notifier)
                                  .state = null,
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          Positioned(
                            left: _railWidth,
                            top: 0.0,
                            bottom: 0.0,
                            width: _flyoutWidth,
                            child: _buildModuleFlyout(
                              context,
                              ref,
                              activeFlyoutModule,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const AppStatusBar(showSyncStatus: true),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Slide-out sub-menu flyout for a collapsed-rail module: elevated surface
  /// anchored to the rail's right edge, with an UPPERCASE '<MODULE> MODULE'
  /// header (so find.text on the bare module label never matches twice) and
  /// one tile per sub-route.
  Widget _buildModuleFlyout(
    BuildContext context,
    WidgetRef ref,
    String moduleId,
  ) {
    final subRoutes = sidebarSubRoutesFor(moduleId);
    final currentPath = _safeCurrentLocation(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
          right: BorderSide(color: AppColors.borderDefault, width: 1.0),
          left: BorderSide(color: AppColors.borderDefault, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12.0,
            offset: Offset(2.0, 0.0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56.0,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            alignment: Alignment.centerLeft,
            child: Text(
              '${moduleId.toUpperCase()} MODULE',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const Divider(height: 1.0, color: AppColors.borderDefault),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              children: [
                for (final sub in subRoutes)
                  InkWell(
                    onTap: () {
                      ref.read(sidebarFlyoutProvider.notifier).state = null;
                      context.go(sub.route);
                    },
                    child: Container(
                      height: 44.0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      color: currentPath == sub.route
                          ? AppColors.brandPrimary.withValues(alpha: 0.10)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Icon(
                            sub.icon,
                            size: 18.0,
                            color: currentPath == sub.route
                                ? AppColors.brandPrimary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              sub.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label.copyWith(
                                color: currentPath == sub.route
                                    ? AppColors.brandPrimary
                                    : AppColors.textPrimary,
                                fontWeight: currentPath == sub.route
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _safeCurrentLocation(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.toString();
    } catch (_) {
      return '/dashboard';
    }
  }

  bool _isRootLocation(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    return path == '/' ||
        path == '/dashboard' ||
        path == '/students' ||
        path == '/fees' ||
        path == '/fees/ledger' ||
        path == '/attendance';
  }

  Widget _buildMobileScaffold(BuildContext context) {
    final currentLocation = _safeCurrentLocation(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final isRoot = _isRootLocation(currentLocation);

    return PopScope(
      canPop: isRoot && currentLocation == '/dashboard',
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
          Navigator.of(context).pop();
          return;
        }
        if (context.canPop()) {
          context.pop();
          return;
        }
        final from = GoRouterState.of(context).uri.queryParameters['from'];
        if (from != null && from.isNotEmpty) {
          context.go(from);
          return;
        }
        final path = Uri.tryParse(currentLocation)?.path ?? currentLocation;
        if (path.startsWith('/students/')) {
          context.go('/students');
          return;
        } else if (path.startsWith('/fees/')) {
          context.go('/fees/ledger');
          return;
        } else if (path != '/dashboard') {
          context.go('/dashboard');
          return;
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceSubtle,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(64.0 + topPadding),
          child: Container(
            color: AppColors.surfaceRaised,
            padding: EdgeInsets.only(top: topPadding),
            child: Stack(
              children: [
                AppTopBar(searchFocusNode: _searchFocusNode, mobile: true),
                if (!isRoot)
                  Positioned(
                    left: 8.0,
                    top: 0.0,
                    bottom: 0.0,
                    width: 48.0,
                    child: Container(
                      color: AppColors.surfaceRaised,
                      alignment: Alignment.center,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: AppColors.textPrimary,
                        tooltip: 'Back',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            final from = GoRouterState.of(context)
                                .uri
                                .queryParameters['from'];
                            if (from != null && from.isNotEmpty) {
                              context.go(from);
                            } else {
                              final path =
                                  Uri.tryParse(currentLocation)?.path ??
                                  currentLocation;
                              if (path.startsWith('/students/')) {
                                context.go('/students');
                              } else if (path.startsWith('/fees/')) {
                                context.go('/fees/ledger');
                              } else {
                                context.go('/dashboard');
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        drawer: const MobileDrawer(),
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Expanded(child: widget.child),
              const AppStatusBar(showSyncStatus: true),
            ],
          ),
        ),
        bottomNavigationBar: MobileBottomNav(currentLocation: currentLocation),
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
