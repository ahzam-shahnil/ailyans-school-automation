import 'package:flutter/material.dart';

import '../../core/theme/app_theme_tokens.dart';

class MobileDropdownField<T> extends StatelessWidget {
  const MobileDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
    super.key,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44.0,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              isDense: true,
              dropdownColor: AppColors.surfaceRaised,
              iconEnabledColor: AppColors.textPrimary,
              iconDisabledColor: AppColors.textMuted,
              style: AppTypography.body.copyWith(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              hint: hintText != null
                  ? Text(
                      hintText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : null,
              selectedItemBuilder: (BuildContext context) {
                return items.map((DropdownMenuItem<T> item) {
                  final child = item.child;
                  final String text = child is Text
                      ? (child.data ?? '')
                      : (item.value?.toString() ?? '');
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ],
    );
  }
}
