import 'package:flutter/material.dart';

import '../../core/theme/app_theme_tokens.dart';

enum MobileStatusVariant {
  success,
  warning,
  error,
  info,
  neutral,
}

class MobileStatusPill extends StatelessWidget {
  const MobileStatusPill({
    required this.label,
    required this.variant,
    super.key,
  });

  final String label;
  final MobileStatusVariant variant;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color text;

    switch (variant) {
      case MobileStatusVariant.success:
        bg = AppColors.statusSuccessBg;
        border = AppColors.statusSuccessBorder;
        text = AppColors.statusSuccessText;
      case MobileStatusVariant.warning:
        bg = AppColors.statusWarningBg;
        border = AppColors.statusWarningBorder;
        text = AppColors.statusWarningText;
      case MobileStatusVariant.error:
        bg = AppColors.statusErrorBg;
        border = AppColors.statusErrorBorder;
        text = AppColors.statusErrorText;
      case MobileStatusVariant.info:
        bg = AppColors.statusInfoBg;
        border = AppColors.statusInfoBorder;
        text = AppColors.statusInfoText;
      case MobileStatusVariant.neutral:
        bg = AppColors.statusNeutralBg;
        border = AppColors.statusNeutralBorder;
        text = AppColors.statusNeutralText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.label.copyWith(
          fontSize: 11,
          color: text,
        ),
      ),
    );
  }
}
