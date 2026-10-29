import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/session_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../repositories/auth_repository.dart';

/// Modal dialog for modifying an operator account password.
/// Follows specifications from 05-ui-ux-spec.md (Screen 2) and 03-behavior-specs.md (S1, S2, S3).
class ChangePasswordDialog extends ConsumerStatefulWidget {
  final String? username;

  const ChangePasswordDialog({super.key, this.username});

  /// Helper to display the [ChangePasswordDialog] over the given context.
  static Future<bool?> show(BuildContext context, {String? username}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ChangePasswordDialog(username: username),
    );
  }

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _currentPasswordFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  String _getEffectiveUsername() {
    if (widget.username != null && widget.username!.trim().isNotEmpty) {
      return widget.username!.trim();
    }
    final sessionUser = ref.read(sessionProvider)?.user.name;
    if (sessionUser != null && sessionUser.trim().isNotEmpty) {
      return sessionUser.trim();
    }
    return 'Operator';
  }

  Future<void> _handleSubmit() async {
    setState(() => _errorMessage = null);

    final username = _getEffectiveUsername();
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // 1. All fields non-empty
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill all fields';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);

      // 2. Verify current password
      final authenticatedUser = await authRepo.authenticate(
        username,
        currentPassword,
      );
      if (authenticatedUser == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'invalid User or Password';
            _currentPasswordController.clear();
            _isLoading = false;
          });
          _currentPasswordFocusNode.requestFocus();
        }
        return;
      }

      // 3. New password min 8 characters
      if (newPassword.length < 8) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Password must be at least 8 characters';
            _isLoading = false;
          });
          _newPasswordFocusNode.requestFocus();
        }
        return;
      }

      // 4. New password == confirm password
      if (newPassword != confirmPassword) {
        if (mounted) {
          setState(() {
            _errorMessage = 'New password and confirm password do not match';
            _isLoading = false;
          });
          _confirmPasswordFocusNode.requestFocus();
        }
        return;
      }

      // 5. New password != current password
      if (currentPassword == newPassword) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'New password must be different from current password';
            _isLoading = false;
          });
          _newPasswordFocusNode.requestFocus();
        }
        return;
      }

      // Execute password change
      final success = await authRepo.changePassword(
        authenticatedUser.id,
        newPassword,
      );
      if (!success) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Password must be at least 8 characters';
            _isLoading = false;
          });
        }
        return;
      }

      // Success
      final sessionNotifier = ref.read(sessionProvider.notifier);
      final currentSession = ref.read(sessionProvider);
      if (currentSession != null) {
        sessionNotifier.dismissWeakPasswordWarning();
        sessionNotifier.updateUser(
          authenticatedUser.copyWith(password: newPassword),
        );
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.statusSuccessText,
                  size: 18.0,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Password Changed',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.statusSuccessText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.statusSuccessBg,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update password: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUsername = _getEffectiveUsername();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        width: 440.0,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderDefault),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 16.0,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_reset_rounded,
                    size: 22.0,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Change Operator Password',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20.0),
                    color: AppColors.textSecondary,
                    tooltip: 'Close',
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.borderDefault),

            // Form Body
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.statusErrorBg,
                        border: Border.all(color: AppColors.statusErrorBorder),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16.0,
                            color: AppColors.statusErrorText,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.statusErrorText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 1. Operator Account (Read-Only)
                  Text(
                    'Operator Account',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Container(
                    height: 40.0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 18.0,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            effectiveUsername,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.borderDefault,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            'Read-only',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 10.0,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Current Password
                  Text(
                    'Current Password *',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  SizedBox(
                    height: 40.0,
                    child: TextField(
                      controller: _currentPasswordController,
                      focusNode: _currentPasswordFocusNode,
                      obscureText: _obscureCurrent,
                      enabled: !_isLoading,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter existing password',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceRaised,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 8.0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                            color: AppColors.borderDefault,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                            color: AppColors.borderDefault,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                            color: AppColors.borderFocus,
                            width: 1.5,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrent
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18.0,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() => _obscureCurrent = !_obscureCurrent);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. New Password
                  Text(
                    'New Password *',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  SizedBox(
                    height: 40.0,
                    child: TextField(
                      controller: _newPasswordController,
                      focusNode: _newPasswordFocusNode,
                      obscureText: _obscureNew,
                      enabled: !_isLoading,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter new password',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceRaised,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 8.0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                            color: AppColors.borderDefault,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                            color: AppColors.borderDefault,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                            color: AppColors.borderFocus,
                            width: 1.5,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18.0,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() => _obscureNew = !_obscureNew);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Minimum 8 characters',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11.0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 4. Confirm New Password
                  Text(
                    'Confirm New Password *',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  SizedBox(
                    height: 40.0,
                    child: TextField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocusNode,
                      obscureText: _obscureConfirm,
                      enabled: !_isLoading,
                      onSubmitted: (_) => _handleSubmit(),
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Confirm new password',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceRaised,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 8.0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                            color: AppColors.borderDefault,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                            color: AppColors.borderDefault,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                            color: AppColors.borderFocus,
                            width: 1.5,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18.0,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() => _obscureConfirm = !_obscureConfirm);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Actions Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(
                            color: AppColors.borderDefault,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        child: const Text('Cancel', style: AppTypography.label),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          foregroundColor: AppColors.surfaceRaised,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16.0,
                                height: 16.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.surfaceRaised,
                                  ),
                                ),
                              )
                            : Text(
                                'Update Password',
                                style: AppTypography.label.copyWith(
                                  color: AppColors.surfaceRaised,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
