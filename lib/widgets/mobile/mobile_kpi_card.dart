import 'package:flutter/material.dart';

import '../../core/theme/app_theme_tokens.dart';
import 'mobile_status_pill.dart';

class MobileKpiCard extends StatelessWidget {
  const MobileKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.accentSoftBg,
    this.statusPillText,
    this.statusVariant,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color accentSoftBg;
  final String? statusPillText;
  final MobileStatusVariant? statusVariant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget card = Container(
      height: 76.0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accentSoftBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 14,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (statusPillText != null && statusVariant != null) ...[
                const SizedBox(width: 6),
                MobileStatusPill(
                  label: statusPillText!,
                  variant: statusVariant!,
                ),
              ],
            ],
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTypography.monospace.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: card,
        ),
      );
    }

    return card;
  }
}
