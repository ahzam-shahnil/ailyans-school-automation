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
    final Widget header;
    final List<Widget> actions;

    switch (kind) {
      case VoucherResultKind.success:
        bg = AppColors.statusSuccessBg;
        border = AppColors.statusSuccessBorder;
        fg = AppColors.statusSuccessText;
        header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$createdCount vouchers created',
              style: AppTypography.h2.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: Rs. ${currencyFormat.format(totalAmount)}',
              style: AppTypography.bodySmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
        actions = [
          OutlinedButton(
            onPressed: onPrintAll,
            style: OutlinedButton.styleFrom(
              foregroundColor: fg,
              side: BorderSide(color: border),
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
          TextButton(
            onPressed: onGenerateAnother,
            style: TextButton.styleFrom(
              foregroundColor: fg,
            ),
            child: const Text('Generate another'),
          ),
        ];
        break;

      case VoucherResultKind.cancelled:
        bg = AppColors.statusInfoBg;
        border = AppColors.statusInfoBorder;
        fg = AppColors.statusInfoText;
        header = Text(
          'Stopped. $createdCount vouchers were created.',
          style: AppTypography.h2.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        );
        actions = [
          OutlinedButton(
            onPressed: onPrintAll,
            style: OutlinedButton.styleFrom(
              foregroundColor: fg,
              side: BorderSide(color: border),
            ),
            child: const Text('Print created'),
          ),
          if (onResumeRemaining != null)
            OutlinedButton(
              onPressed: onResumeRemaining,
              style: OutlinedButton.styleFrom(
                foregroundColor: fg,
                side: BorderSide(color: border),
              ),
              child: const Text('Resume'),
            ),
        ];
        break;

      case VoucherResultKind.partial:
        bg = AppColors.statusWarningBg;
        border = AppColors.statusWarningBorder;
        fg = AppColors.statusWarningText;
        final notCreated = totalCount - createdCount;
        header = Text(
          '$createdCount of $totalCount vouchers created. $notCreated not created.',
          style: AppTypography.h2.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        );
        actions = [
          if (onResumeRemaining != null)
            OutlinedButton(
              onPressed: onResumeRemaining,
              style: OutlinedButton.styleFrom(
                foregroundColor: fg,
                side: BorderSide(color: border),
              ),
              child: const Text('Resume remaining'),
            ),
          OutlinedButton(
            onPressed: onPrintAll,
            style: OutlinedButton.styleFrom(
              foregroundColor: fg,
              side: BorderSide(color: border),
            ),
            child: Text('Print the $createdCount created'),
          ),
        ];
        break;
    }

    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: actions,
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
