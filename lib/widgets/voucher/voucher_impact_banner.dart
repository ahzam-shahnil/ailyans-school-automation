import 'package:flutter/material.dart';

import '../../core/theme/app_theme_tokens.dart';

enum VoucherImpactState { normal, zero, error }

/// Status banner communicating the impact of the current voucher parameters.
class VoucherImpactBanner extends StatelessWidget {
  const VoucherImpactBanner({
    required this.state,
    required this.count,
    this.errorText,
    super.key,
  });

  final VoucherImpactState state;
  final int count;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color fg;
    final IconData icon;
    final String text;

    switch (state) {
      case VoucherImpactState.normal:
        bg = AppColors.statusInfoBg;
        border = AppColors.statusInfoBorder;
        fg = AppColors.statusInfoText;
        icon = Icons.info_outline;
        text = '$count vouchers will be created in VoucharMas + VoucharDet';
        break;
      case VoucherImpactState.zero:
        bg = AppColors.statusWarningBg;
        border = AppColors.statusWarningBorder;
        fg = AppColors.statusWarningText;
        icon = Icons.warning_amber_rounded;
        text = '0 vouchers will be created';
        break;
      case VoucherImpactState.error:
        bg = AppColors.statusErrorBg;
        border = AppColors.statusErrorBorder;
        fg = AppColors.statusErrorText;
        icon = Icons.error_outline;
        text = errorText ?? 'Fix fields to continue';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                text,
                style: AppTypography.bodySmall.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
