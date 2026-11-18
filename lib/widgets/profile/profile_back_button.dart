import 'package:flutter/material.dart';
import '../../core/theme/app_theme_tokens.dart';

class ProfileBackButton extends StatelessWidget {
  const ProfileBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Back',
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('profile_back_button'),
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded, size: 20),
      tooltip: tooltip,
      color: AppColors.textSecondary,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}
