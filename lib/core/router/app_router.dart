import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../screens/academics/class_section_screen.dart';
import '../../screens/academics/subject_catalog_screen.dart';
import '../../screens/attendance/attendance_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/exams/class_subject_mapping_screen.dart';
import '../../screens/exams/exam_term_screen.dart';
import '../../screens/exams/marks_entry_screen.dart';
import '../../screens/fees/fee_collection_screen.dart';
import '../../screens/fees/fee_ledger_screen.dart';
import '../../screens/fees/fee_parameter_screen.dart';
import '../../screens/fees/voucher_generation_screen.dart';
import '../../screens/library/book_profile_screen.dart';
import '../../screens/library/library_books_screen.dart';
import '../../screens/login/login_screen.dart';
import '../../screens/search/global_search_screen.dart';
import '../../screens/setup/license_entry_screen.dart';
import '../../screens/setup/school_setup_screen.dart';
import '../../screens/staff/salary_management_screen.dart';
import '../../screens/staff/teacher_list_screen.dart';
import '../../screens/staff/teacher_profile_screen.dart';
import '../../screens/students/batch_promotion_screen.dart';
import '../../screens/students/bulk_enrollment_screen.dart';
import '../../screens/students/school_leaving_screen.dart';
import '../../screens/students/student_list_screen.dart';
import '../../screens/students/student_profile_screen.dart';
import '../../screens/students/student_registration_wizard.dart';
import '../../screens/system/permission_matrix_screen.dart';
import '../../screens/system/system_settings_screen.dart';
import '../../screens/system/user_management_screen.dart';
import '../../widgets/shell/app_shell.dart';
import '../providers/license_provider.dart';
import '../providers/session_provider.dart';
import '../providers/tenant_provider.dart';
import '../theme/app_theme_tokens.dart';

/// Helper checking whether a route is permitted for the given authenticated [session].
bool _isRouteAllowed(String location, UserSession session) {
  if (session.user.userLevel == 1) return true;

  // Guard against redirect loops: if user has 0 modules assigned, allow /dashboard
  if (session.allowedObjIds.isEmpty && location == '/dashboard') {
    return true;
  }

  final allowedSet = session.allowedObjIds.toSet();

  // /system/settings -> userLevel == 1 only
  if (location.startsWith('/system/settings')) {
    return false;
  }

  // /system/users, /system/permissions -> [1] (or userLevel == 1)
  if (location.startsWith('/system/users') ||
      location.startsWith('/system/permissions')) {
    return allowedSet.contains(1);
  }

  // /search -> allowed if user has Students, Fees, Staff, or Library permissions
  if (location.startsWith('/search')) {
    const searchObjIds = {
      1,
      3,
      8,
      9,
      11,
      12,
      13,
      14,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      26,
      29,
    };
    return allowedSet.intersection(searchObjIds).isNotEmpty;
  }

  if (location.startsWith('/dashboard')) {
    return allowedSet.contains(1);
  }

  // Specific sub-routes under /students
  if (location.startsWith('/students/new')) {
    return allowedSet.contains(26) || allowedSet.contains(12);
  }
  if (location.startsWith('/students/enrollment/bulk')) {
    return allowedSet.contains(20);
  }
  if (location.startsWith('/students/promote')) {
    return allowedSet.contains(8);
  }
  if (location.startsWith('/students/leaving')) {
    return allowedSet.contains(9);
  }
  if (location.startsWith('/students')) {
    return allowedSet.intersection(const {8, 9, 11, 12, 13, 20, 26}).isNotEmpty;
  }

  if (location.startsWith('/academics')) {
    return allowedSet.intersection(const {4}).isNotEmpty;
  }

  // Specific sub-routes under /fees
  if (location.startsWith('/fees/parameters')) {
    return allowedSet.contains(21) || allowedSet.contains(19);
  }
  if (location.startsWith('/fees/vouchers')) {
    return allowedSet.contains(17);
  }
  if (location.startsWith('/fees/receipts')) {
    return allowedSet.contains(16);
  }
  if (location.startsWith('/fees/ledger')) {
    return allowedSet.contains(18);
  }
  if (location.startsWith('/fees')) {
    return allowedSet.intersection(const {16, 17, 18, 19, 21}).isNotEmpty;
  }

  // Specific sub-routes under /exams
  if (location.startsWith('/exams/terms')) {
    return allowedSet.contains(10);
  }
  if (location.startsWith('/exams/subjects')) {
    return allowedSet.contains(23);
  }
  if (location.startsWith('/exams/marks')) {
    return allowedSet.contains(24);
  }
  if (location.startsWith('/exams')) {
    return allowedSet.intersection(const {10, 23, 24}).isNotEmpty;
  }

  if (location.startsWith('/attendance')) {
    return allowedSet.intersection(const {2, 28}).isNotEmpty;
  }

  // Specific sub-routes under /staff
  if (location.startsWith('/staff/salary')) {
    return allowedSet.contains(22) || allowedSet.contains(29);
  }
  if (location.startsWith('/staff/teachers')) {
    return allowedSet.contains(14);
  }
  if (location.startsWith('/staff')) {
    return allowedSet.intersection(const {14, 22, 29}).isNotEmpty;
  }

  if (location.startsWith('/library')) {
    return allowedSet.intersection(const {3}).isNotEmpty;
  }

  return true;
}

/// Helper returning the first permitted route for [session] in deterministic module order.
String _firstAllowedRoute(UserSession session) {
  if (session.user.userLevel == 1) return '/dashboard';

  final allowedSet = session.allowedObjIds.toSet();

  // 1. Dashboard
  if (allowedSet.contains(1)) return '/dashboard';

  // 2. Students
  if (allowedSet.intersection(const {8, 9, 11, 12, 13, 20, 26}).isNotEmpty) {
    return '/students';
  }

  // 3. Fees: Check vouchers (#17), receipts (#16), ledger (#18), parameters (#21/#19)
  if (allowedSet.contains(17)) return '/fees/vouchers';
  if (allowedSet.contains(16)) return '/fees/receipts';
  if (allowedSet.contains(18)) return '/fees/ledger';
  if (allowedSet.contains(21) || allowedSet.contains(19)) {
    return '/fees/parameters';
  }

  // 4. Attendance
  if (allowedSet.intersection(const {2, 28}).isNotEmpty) {
    return '/attendance';
  }

  // 5. Staff: Check teachers (#14), salary (#22/#29)
  if (allowedSet.contains(14)) return '/staff/teachers';
  if (allowedSet.contains(22) || allowedSet.contains(29)) {
    return '/staff/salary';
  }

  // 6. Exams: Check marks (#24), terms (#10), subjects (#23)
  if (allowedSet.contains(24)) return '/exams/marks';
  if (allowedSet.contains(10)) return '/exams/terms';
  if (allowedSet.contains(23)) return '/exams/subjects';

  // 7. Library
  if (allowedSet.contains(3)) return '/library';

  // 8. Academics
  if (allowedSet.contains(4)) return '/academics/classes';

  return '/dashboard';
}

/// Notifier that triggers GoRouter refresh when authentication session,
/// active tenant (G-10 Shot 2), or license activation (G-10 Shot 4) changes.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<UserSession?>(sessionProvider, (_, __) {
      notifyListeners();
    });
    _ref.listen<Tenant?>(tenantProvider, (_, __) {
      notifyListeners();
    });
    _ref.listen<License?>(licenseProvider, (_, __) {
      notifyListeners();
    });
  }

  /// Public refresh hook for async bootstraps (e.g. tenant load).
  void refresh() => notifyListeners();
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

/// Global Riverpod provider configuring the application GoRouter instance.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  // G-10 Shot 2: resolve the persisted tenant (if any) once at startup, then
  // refresh the router so the first-launch gate can route to /setup.
  final tenantNotifier = ref.read(tenantProvider.notifier);
  unawaited(tenantNotifier.loadTenant().then((_) => notifier.refresh()));

  // G-10 Shot 4: resolve the persisted license (if any) once at startup,
  // then refresh so the license gate routes activated installs onward.
  final licenseNotifier = ref.read(licenseProvider.notifier);
  unawaited(licenseNotifier.loadLicense().then((_) => notifier.refresh()));

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (BuildContext context, GoRouterState state) {
      final session = ref.read(sessionProvider);
      final isAuthenticated = session != null;
      final location = state.matchedLocation;

      // G-10 Shot 2: first-launch tenant gate. Only evaluated once the
      // tenant provider has actually consulted SharedPreferences (inert in
      // widget tests, where the platform channel is unavailable).
      final tenant = ref.read(tenantProvider);
      final tenantNotifier = ref.read(tenantProvider.notifier);
      final tenantLoaded = tenantNotifier.loaded;

      // G-10 Shot 4: license activation gate. Only evaluated once the
      // license provider has consulted SharedPreferences (inert in widget
      // tests, where the platform channel is unavailable).
      final license = ref.read(licenseProvider);
      final licenseLoaded = ref.read(licenseProvider.notifier).loaded;
      final hasValidLicense = license != null && license.isCurrentlyValid;

      final isSetup = location == '/setup';
      final isLicense = location == '/license';
      if (tenantLoaded && tenant == null && !isSetup) {
        return '/setup';
      }
      if (tenantLoaded && tenant != null) {
        // License gate: tenant provisioned but no valid activation yet —
        // every route except the license screen is blocked.
        if (licenseLoaded && !hasValidLicense && !isLicense) {
          return '/license';
        }
        // Activated installs skip the setup wizard and license screen.
        if (hasValidLicense && (isLicense || isSetup)) {
          return isAuthenticated ? _firstAllowedRoute(session) : '/login';
        }
        if (isSetup) {
          return '/dashboard';
        }
      }

      final isSplash = location == '/';
      final isLogin = location == '/login';

      // Redirect unauthenticated users to /login (unless on / or /login).
      // /setup and /license are also exempt: the first-launch wizard and
      // license activation must be reachable before any operator has signed
      // in (G-10 Shot 2 / Shot 4).
      if (!isAuthenticated &&
          !isLogin &&
          !isSplash &&
          !isSetup &&
          !(isLicense && !hasValidLicense)) {
        return '/login';
      }

      // If already authenticated and visiting /login or /, go straight to first allowed route
      if (isAuthenticated && (isLogin || isSplash)) {
        return _firstAllowedRoute(session);
      }

      // If authenticated and userLevel != 1, enforce strict RBAC permissions
      if (isAuthenticated && session.user.userLevel != 1) {
        // If Level 2+ operator accesses /dashboard without dashboard permissions (ObjID 1)
        if (location == '/dashboard' || location.startsWith('/dashboard')) {
          final hasDashboardPerms = session.allowedObjIds.contains(1);
          if (!hasDashboardPerms) {
            // If they have NO allowed modules, keep them on /dashboard so they see Access Restricted card
            if (session.allowedObjIds.isEmpty) {
              return null;
            }
            // Automatically redirect them to their FIRST ALLOWED module (e.g. /attendance)
            final target = _firstAllowedRoute(session);
            if (target != '/dashboard') {
              return target;
            }
            return null;
          }
        }

        if (!_isRouteAllowed(location, session)) {
          // If accessing /fees/* without sub-route permission, redirect to allowed fee sub-route
          if (location.startsWith('/fees')) {
            if (session.hasAccess(17)) return '/fees/vouchers';
            if (session.hasAccess(16)) return '/fees/receipts';
            if (session.hasAccess(18)) return '/fees/ledger';
            if (session.hasAccess(21) || session.hasAccess(19)) {
              return '/fees/parameters';
            }
          }
          // If accessing /staff/* without sub-route permission, redirect to allowed staff sub-route
          if (location.startsWith('/staff')) {
            if (session.hasAccess(14)) return '/staff/teachers';
            if (session.hasAccess(22) || session.hasAccess(29)) {
              return '/staff/salary';
            }
          }
          // If accessing /exams/* without sub-route permission, redirect to allowed exams sub-route
          if (location.startsWith('/exams')) {
            if (session.hasAccess(24)) return '/exams/marks';
            if (session.hasAccess(10)) return '/exams/terms';
            if (session.hasAccess(23)) return '/exams/subjects';
          }
          final target = _firstAllowedRoute(session);
          return target != location ? target : null;
        }
      }

      return null;
    },
    routes: [
      // 1. Top-Level Unauthenticated Routes (No Shell)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // G-10 Shot 2: first-launch school setup wizard (root navigator, no shell)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/setup',
        builder: (context, state) => const SchoolSetupScreen(),
      ),

      // G-10 Shot 4: SaaS license activation gate (root navigator, no shell)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/license',
        builder: (context, state) => const LicenseEntryScreen(),
      ),

      // 2. Authenticated Routes Wrapped in Persistent Desktop AppShell
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          final isDashboard = state.matchedLocation == '/dashboard';
          return PopScope(
            canPop: isDashboard,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              final shellNav = _shellNavigatorKey.currentState;
              if (shellNav != null && shellNav.canPop()) {
                shellNav.pop();
                return;
              }
              final rootNav = _rootNavigatorKey.currentState;
              if (rootNav != null && rootNav.canPop()) {
                rootNav.pop();
                return;
              }
              final from = state.uri.queryParameters['from'];
              if (from != null && from.isNotEmpty) {
                context.go(from);
              } else {
                context.go('/dashboard');
              }
            },
            child: AppShell(child: child),
          );
        },
        routes: [
          GoRoute(
            path: '/search',
            builder: (context, state) {
              final q = state.uri.queryParameters['q'] ?? '';
              final from = state.uri.queryParameters['from'];
              return GlobalSearchScreen(initialQuery: q, fromOrigin: from);
            },
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/students',
            builder: (context, state) => const StudentListScreen(),
            routes: [
              // CRITICAL: 'enrollment/bulk', 'promote', and 'new' MUST precede ':id' to prevent routing conflicts
              GoRoute(
                path: 'enrollment/bulk',
                builder: (context, state) => const BulkEnrollmentScreen(),
              ),
              GoRoute(
                path: 'promote',
                builder: (context, state) => const BatchPromotionScreen(),
              ),
              GoRoute(
                path: 'leaving',
                builder: (context, state) => const SchoolLeavingScreen(),
              ),
              GoRoute(
                path: 'new',
                builder: (context, state) => const StudentRegistrationWizard(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return StudentProfileScreen(studentId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/academics',
            redirect: (context, state) => '/academics/classes',
          ),
          GoRoute(
            path: '/academics/classes',
            builder: (context, state) => const ClassSectionScreen(),
          ),
          GoRoute(
            path: '/academics/subjects',
            builder: (context, state) => const SubjectCatalogScreen(),
          ),
          GoRoute(
            path: '/fees',
            redirect: (context, state) {
              final session = ref.read(sessionProvider);
              if (session != null && session.user.userLevel != 1) {
                if (session.hasAccess(17)) return '/fees/vouchers';
                if (session.hasAccess(16)) return '/fees/receipts';
                if (session.hasAccess(18)) return '/fees/ledger';
                if (session.hasAccess(21) || session.hasAccess(19)) {
                  return '/fees/parameters';
                }
              }
              return '/fees/vouchers';
            },
          ),
          GoRoute(
            path: '/fees/parameters',
            builder: (context, state) => const FeeParameterScreen(),
          ),
          GoRoute(
            path: '/fees/vouchers',
            builder: (context, state) => const VoucherGenerationScreen(),
          ),
          GoRoute(
            path: '/fees/receipts',
            builder: (context, state) => const FeeCollectionScreen(),
          ),
          GoRoute(
            path: '/fees/ledger',
            builder: (context, state) => const FeeLedgerScreen(),
          ),
          GoRoute(
            path: '/exams',
            redirect: (context, state) {
              final session = ref.read(sessionProvider);
              if (session != null && session.user.userLevel != 1) {
                if (session.hasAccess(24)) return '/exams/marks';
                if (session.hasAccess(10)) return '/exams/terms';
                if (session.hasAccess(23)) return '/exams/subjects';
              }
              return '/exams/marks';
            },
          ),
          GoRoute(
            path: '/exams/terms',
            builder: (context, state) => const ExamTermScreen(),
          ),
          GoRoute(
            path: '/exams/subjects',
            builder: (context, state) => const ClassSubjectMappingScreen(),
          ),
          GoRoute(
            path: '/exams/marks',
            builder: (context, state) => const MarksEntryScreen(),
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/staff/teachers',
            builder: (context, state) => const TeacherListScreen(),
          ),
          GoRoute(
            path: '/staff/teachers/new',
            builder: (context, state) =>
                const TeacherProfileScreen(isCreateMode: true),
          ),
          GoRoute(
            path: '/staff/salary',
            builder: (context, state) => const SalaryManagementScreen(),
          ),
          GoRoute(
            path: '/staff/teachers/:id',
            builder: (context, state) {
              final idStr = state.pathParameters['id'];
              final id = idStr != null ? int.tryParse(idStr) : null;
              return TeacherProfileScreen(teacherId: id);
            },
          ),
          GoRoute(
            path: '/staff',
            redirect: (context, state) {
              final session = ref.read(sessionProvider);
              if (session != null && session.user.userLevel != 1) {
                if (!session.hasAccess(14) &&
                    (session.hasAccess(22) || session.hasAccess(29))) {
                  return '/staff/salary';
                }
              }
              return '/staff/teachers';
            },
          ),
          GoRoute(
            path: '/library',
            builder: (context, state) => const LibraryBooksScreen(),
          ),
          GoRoute(
            path: '/library/new',
            builder: (context, state) =>
                const BookProfileScreen(bookIdParam: 'new'),
          ),
          GoRoute(
            path: '/library/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? 'new';
              return BookProfileScreen(bookIdParam: id);
            },
          ),
          GoRoute(
            path: '/system/settings',
            builder: (context, state) => const SystemSettingsScreen(),
          ),
          GoRoute(
            path: '/system/users',
            builder: (context, state) => const UserManagementScreen(),
          ),
          GoRoute(
            path: '/system/permissions',
            builder: (context, state) => const PermissionMatrixScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Generic placeholder screen for secondary shell routes.
// ignore: unused_element
class _GenericShellPlaceholder extends StatelessWidget {
  final String title;
  final String route;

  const _GenericShellPlaceholder({required this.title, required this.route});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppTypography.h1.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Route: $route',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Splash Screen at / that auto-redirects after 500ms.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final session = ref.read(sessionProvider);
      if (session != null) {
        context.go('/dashboard');
      } else {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Ailyans School Automation System",
              style: AppTypography.h1.copyWith(color: AppColors.brandPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3.0,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.brandPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
