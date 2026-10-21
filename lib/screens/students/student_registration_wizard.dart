import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme_tokens.dart';

/// Student Registration Wizard Screen stub hosted within [AppShell].
class StudentRegistrationWizard extends StatelessWidget {
  const StudentRegistrationWizard({super.key});

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
              'Student Registration Wizard',
              style: AppTypography.h1.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Active Route: /students/new',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => context.go('/students'),
                  child: const Text('Back to Students Directory'),
                ),
                OutlinedButton(
                  onPressed: () => context.go('/dashboard'),
                  child: const Text('Dashboard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
