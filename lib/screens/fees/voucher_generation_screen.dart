import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme_tokens.dart';

/// Voucher Generation Screen stub hosted within [AppShell].
class VoucherGenerationScreen extends StatelessWidget {
  const VoucherGenerationScreen({super.key});

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
              'Voucher Generation Screen',
              style: AppTypography.h1.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Active Route: /fees/vouchers',
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
                  onPressed: () => context.go('/fees/receipts'),
                  child: const Text('Go to Fee Receipts'),
                ),
                OutlinedButton(
                  onPressed: () => context.go('/dashboard'),
                  child: const Text('Back to Dashboard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
