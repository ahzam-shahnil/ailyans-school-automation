import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../screens/attendance/attendance_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/exams/marks_entry_screen.dart';
import '../../screens/fees/fee_collection_screen.dart';
import '../../screens/fees/fee_parameter_screen.dart';
import '../../screens/fees/voucher_generation_screen.dart';
import '../../screens/login/login_screen.dart';
import '../../screens/students/student_list_screen.dart';
import '../../screens/students/student_profile_screen.dart';
import '../../screens/students/student_registration_wizard.dart';
import '../../screens/system/permission_matrix_screen.dart';
import '../../screens/system/user_management_screen.dart';
import '../../widgets/shell/app_shell.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme_tokens.dart';

/// Notifier that triggers GoRouter refresh when authentication session changes.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<UserSession?>(sessionProvider, (_, __) {
      notifyListeners();
    });
  }
}

/// Global Riverpod provider configuring the application GoRouter instance.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (BuildContext context, GoRouterState state) {
      final session = ref.read(sessionProvider);
      final isAuthenticated = session != null;
      final location = state.matchedLocation;

      final isSplash = location == '/';
      final isLogin = location == '/login';

      // Redirect unauthenticated users to /login (unless on / or /login)
      if (!isAuthenticated && !isLogin && !isSplash) {
        return '/login';
      }

      // If already authenticated and visiting /login or /, go straight to dashboard
      if (isAuthenticated && (isLogin || isSplash)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // 1. Top-Level Unauthenticated Routes (No Shell)
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      // 2. Authenticated Routes Wrapped in Persistent Desktop AppShell
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/students',
            builder: (context, state) => const StudentListScreen(),
            routes: [
              // CRITICAL: 'new' MUST precede ':id' to prevent routing conflicts
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
            builder: (context, state) => const _GenericShellPlaceholder(
              title: 'Academics & Classes',
              route: '/academics',
            ),
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
          GoRoute(path: '/exams', redirect: (context, state) => '/exams/marks'),
          GoRoute(
            path: '/exams/marks',
            builder: (context, state) => const MarksEntryScreen(),
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/staff',
            builder: (context, state) => const _GenericShellPlaceholder(
              title: 'Staff & Payroll',
              route: '/staff',
            ),
          ),
          GoRoute(
            path: '/library',
            builder: (context, state) => const _GenericShellPlaceholder(
              title: 'Library Catalog',
              route: '/library',
            ),
          ),
          GoRoute(
            path: '/system/settings',
            redirect: (context, state) => '/system/users',
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
