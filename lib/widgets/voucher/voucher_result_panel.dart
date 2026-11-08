import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme_tokens.dart';

enum VoucherResultKind { success, cancelled, partial }

/// Completion / interrupted panel summarizing batch generation outcome with actionable exports.
class VoucherResultPanel extends StatelessWidget {
  const VoucherResultPanel({
    required this.kind,
    required this.createdCount,
    required this.totalCount,
    required this.totalAmount,
    required this.onPrintAll,
    required this.onSavePdf,
    required this.onShare,
    required this.onGenerateAnother,
    required this.onResumeRemaining,
    super.key,
  });

  final VoucherResultKind kind;
  final int createdCount;
  final int totalCount;
  final int totalAmount;
  final VoidCallback onPrintAll;
  final VoidCallback onSavePdf;
  final VoidCallback? onShare;
  final VoidCallback onGenerateAnother;
  final VoidCallback? onResumeRemaining;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final currencyFormat = NumberFormat('#,##0');

    final Color bg;
    final Color border;
    final Color fg;
    final IconData icon;
    final String title;
    final List<Widget> actions;

    switch (kind) {
      case VoucherResultKind.success:
        bg = AppStatusPill.readyBg;
        border = AppStatusPill.readyBorder;
        fg = AppStatusPill.readyText;
        icon = Icons.check_circle_outline;
        title = '$createdCount vouchers created';
        actions = [
          ElevatedButton(
            onPressed: onPrintAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Print all'),
          ),
          OutlinedButton(
            onPressed: onSavePdf,
            style: OutlinedButton.styleFrom(
              foregroundColor: fg,
              side: BorderSide(color: border),
            ),
            child: const Text('Save PDF'),
          ),
          if (onShare != null)
            OutlinedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined, size: 16),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(
                foregroundColor: fg,
                side: BorderSide(color: border),
              ),
            ),
          OutlinedButton(
            onPressed: onGenerateAnother,
            style: OutlinedButton.styleFrom(
              foregroundColor: fg,
              side: BorderSide(color: border),
            ),
            child: const Text('Generate another'),
          ),
        ];
        break;

      case VoucherResultKind.cancelled:
        bg = AppStatusPill.waiverBg;
        border = AppStatusPill.waiverBorder;
        fg = AppStatusPill.waiverText;
        icon = Icons.info_outline;
        title = 'Stopped. $createdCount vouchers were created.';
        actions = [
          if (onResumeRemaining != null)
            ElevatedButton(
              onPressed: onResumeRemaining,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.textOnPrimary,
              ),
              child: const Text('Resume'),
            ),
          OutlinedButton(
            onPressed: onPrintAll,
            style: OutlinedButton.styleFrom(
              foregroundColor: fg,
              side: BorderSide(color: border),
            ),
            child: const Text('Print created'),
          ),
        ];
        break;

      case VoucherResultKind.partial:
        bg = AppStatusPill.rolloverBg;
        border = AppStatusPill.rolloverBorder;
        fg = AppStatusPill.rolloverText;
        icon = Icons.warning_amber_rounded;
        final notCreated = totalCount - createdCount;
        title =
            '$createdCount of $totalCount vouchers created. $notCreated not created.';
        actions = [
          if (onResumeRemaining != null)
            ElevatedButton(
              onPressed: onResumeRemaining,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.textOnPrimary,
              ),
              child: const Text('Resume remaining'),
            ),
          OutlinedButton(
            onPressed: onPrintAll,
            style: OutlinedButton.styleFrom(
              foregroundColor: fg,
              side: BorderSide(color: border),
            ),
            child: const Text('Print created'),
          ),
        ];
        break;
    }

    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 32, color: fg),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.h2.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Total: Rs. ${currencyFormat.format(totalAmount)}',
            semanticsLabel:
                'Total Billed: Rs. ${currencyFormat.format(totalAmount)}',
            style: AppTypography.body.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 600) {
                return Row(
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      actions[i],
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: actions,
              );
            },
          ),
        ],
      ),
    );

    if (reduceMotion) {
      return content;
    }

    return AnimatedOpacity(
      opacity: 1.0,
      duration: AppDuration.normal,
      child: content,
    );
  }
}
