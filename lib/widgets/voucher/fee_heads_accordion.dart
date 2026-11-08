import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme_tokens.dart';

/// Presentation model representing an individual fee head in the accordion.
class FeeHeadItem {
  const FeeHeadItem({
    required this.feeParamId,
    required this.name,
    required this.amount,
    required this.isChecked,
  });

  final int feeParamId;
  final String name;
  final int amount;
  final bool isChecked;
}

/// Collapsible accordion displaying cohort fee heads with include/exclude toggles.
class FeeHeadsAccordion extends StatefulWidget {
  const FeeHeadsAccordion({
    required this.heads,
    required this.isLoading,
    required this.errorMessage,
    required this.noTariffMessage,
    required this.onToggleHead,
    required this.onRetry,
    required this.onOpenFeeParams,
    this.onEditTariffs,
    super.key,
  });

  final List<FeeHeadItem> heads;
  final bool isLoading;
  final String? errorMessage;
  final String? noTariffMessage;
  final ValueChanged<int> onToggleHead;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenFeeParams;
  final VoidCallback? onEditTariffs;

  @override
  State<FeeHeadsAccordion> createState() => _FeeHeadsAccordionState();
}

class _FeeHeadsAccordionState extends State<FeeHeadsAccordion> {
  bool _isExpanded = false;

  Widget _buildSkeletonRows() {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          key: ValueKey('fee_head_skeleton_$index'),
          height: 36,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 1,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.statusErrorBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.statusErrorBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.errorMessage!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusErrorText,
              ),
            ),
          ),
          if (widget.onRetry != null)
            OutlinedButton(
              onPressed: widget.onRetry,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.statusErrorBorder),
                foregroundColor: AppColors.statusErrorText,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _buildNoTariffCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.statusInfoBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.statusInfoBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.noTariffMessage!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusInfoText,
              ),
            ),
          ),
          if (widget.onOpenFeeParams != null)
            TextButton(
              onPressed: widget.onOpenFeeParams,
              child: const Text('Open Fee Parameters'),
            ),
        ],
      ),
    );
  }

  Widget _buildHeadRow(FeeHeadItem item) {
    final currencyFormat = NumberFormat('#,##0');
    return InkWell(
      onTap: () => widget.onToggleHead(item.feeParamId),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Checkbox(
              value: item.isChecked,
              activeColor: AppColors.brandPrimary,
              onChanged: (_) => widget.onToggleHead(item.feeParamId),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: Text(
                item.name,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Rs. ${currencyFormat.format(item.amount)}',
              style: AppTypography.monospace.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadsGrid(BoxConstraints constraints) {
    if (constraints.maxWidth < 480) {
      return Column(
        children: widget.heads.map(_buildHeadRow).toList(),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < widget.heads.length; i += 2) {
      final item1 = widget.heads[i];
      final item2 = i + 1 < widget.heads.length ? widget.heads[i + 1] : null;

      rows.add(
        Row(
          children: [
            Expanded(child: _buildHeadRow(item1)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: item2 != null ? _buildHeadRow(item2) : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildLoadedBody(BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeadsGrid(constraints),
        if (widget.onEditTariffs != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onEditTariffs,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Edit tariffs', style: TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final totalChecked = widget.heads
        .where((h) => h.isChecked)
        .fold<int>(0, (sum, h) => sum + h.amount);
    final formattedAmount = NumberFormat('#,##0').format(totalChecked);
    final count = widget.heads.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$count fee heads · Rs $formattedAmount per student',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              reduceMotion
                  ? (_isExpanded
                      ? Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.md,
                            right: AppSpacing.md,
                            bottom: AppSpacing.md,
                          ),
                          child: widget.isLoading
                              ? _buildSkeletonRows()
                              : widget.errorMessage != null
                                  ? _buildErrorCard()
                                  : widget.noTariffMessage != null
                                      ? _buildNoTariffCard()
                                      : _buildLoadedBody(constraints),
                        )
                      : const SizedBox.shrink())
                  : AnimatedSize(
                      duration: AppDuration.normal,
                      curve: Curves.easeInOut,
                      child: _isExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.md,
                                right: AppSpacing.md,
                                bottom: AppSpacing.md,
                              ),
                              child: widget.isLoading
                                  ? _buildSkeletonRows()
                                  : widget.errorMessage != null
                                      ? _buildErrorCard()
                                      : widget.noTariffMessage != null
                                          ? _buildNoTariffCard()
                                          : _buildLoadedBody(constraints),
                            )
                          : const SizedBox.shrink(),
                    ),
            ],
          );
        },
      ),
    );
  }
}
