import 'package:flutter/material.dart';

import '../../core/theme/app_theme_tokens.dart';
import 'voucher_impact_banner.dart';

/// Sticky action bar at the bottom of the voucher screen hosting the impact banner and Generate trigger.
class VoucherActionBar extends StatelessWidget {
  const VoucherActionBar({
    required this.impactState,
    required this.count,
    required this.errorText,
    required this.isGenerating,
    required this.onGenerate,
    super.key,
  });

  final VoucherImpactState impactState;
  final int count;
  final String? errorText;
  final bool isGenerating;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
          top: BorderSide(color: AppColors.borderDefault),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          final isDisabled = onGenerate == null;

          final generateButton = SizedBox(
            height: 48,
            width: isWide ? null : double.infinity,
            child: ElevatedButton.icon(
              onPressed: isGenerating
                  ? null
                  : (isDisabled ? () {} : onGenerate),
              icon: isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textMuted,
                      ),
                    )
                  : const Icon(Icons.play_arrow, size: 20),
              label: Text(
                isGenerating ? 'Generating...' : 'Generate',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDisabled
                    ? AppColors.surfaceSubtle
                    : AppColors.brandPrimary,
                foregroundColor: isDisabled
                    ? AppColors.textMuted
                    : Colors.white,
                disabledBackgroundColor: AppColors.surfaceSubtle,
                disabledForegroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  child: VoucherImpactBanner(
                    state: impactState,
                    count: count,
                    errorText: errorText,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                generateButton,
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VoucherImpactBanner(
                state: impactState,
                count: count,
                errorText: errorText,
              ),
              const SizedBox(height: AppSpacing.sm),
              generateButton,
            ],
          );
        },
      ),
    );
  }
}
