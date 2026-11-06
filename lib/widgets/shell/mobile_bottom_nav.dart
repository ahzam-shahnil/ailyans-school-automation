import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/session_provider.dart';
import '../../core/theme/app_theme_tokens.dart';

/// Phase G-2 — Mobile 4-tab BottomNavigationBar (<600px).
/// RBAC-filtered via session.allowedObjIds.
class MobileBottomNav extends ConsumerWidget {
  final String currentLocation;

  const MobileBottomNav({super.key, required this.currentLocation});

  static const List<
    ({
      String label,
      String route,
      String matchPrefix,
      IconData icon,
      List<int> objIds,
    })
  >
  _allTabs = [
    (
      label: 'Home',
      route: '/dashboard',
      matchPrefix: '/dashboard',
      icon: Icons.dashboard_outlined,
      objIds: [1],
    ),
    (
      label: 'Students',
      route: '/students',
      matchPrefix: '/students',
      icon: Icons.people_outline,
      objIds: [8, 9, 11, 12, 13, 20, 26],
    ),
    (
      label: 'Fees',
      route: '/fees/ledger',
      matchPrefix: '/fees',
      icon: Icons.receipt_long_outlined,
      objIds: [16, 17, 18, 19, 21],
    ),
    (
      label: 'Attendance',
      route: '/attendance',
      matchPrefix: '/attendance',
      icon: Icons.check_circle_outline,
      objIds: [2, 28],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final allowed = session?.allowedObjIds ?? const <int>[];
    final isUnrestricted = session == null || session.user.userLevel == 1;

    final visible = _allTabs
        .where((t) => isUnrestricted || t.objIds.any(allowed.contains))
        .toList();

    // BottomNavigationBar requires at least 2 items.
    if (visible.length < 2) {
      return const SizedBox.shrink();
    }

    int currentIndex = 0;
    for (var i = 0; i < visible.length; i++) {
      if (currentLocation.startsWith(visible[i].matchPrefix)) {
        currentIndex = i;
        break;
      }
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.surfaceRaised,
      selectedItemColor: AppColors.brandPrimary,
      unselectedItemColor: AppColors.textSecondary,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      onTap: (i) {
        try {
          context.go(visible[i].route);
        } catch (_) {}
      },
      items: visible
          .map(
            (t) => BottomNavigationBarItem(icon: Icon(t.icon), label: t.label),
          )
          .toList(),
    );
  }
}
