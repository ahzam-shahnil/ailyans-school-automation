import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/providers/backup_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/shell_metadata_provider.dart';
import '../../core/providers/tenant_provider.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/shell/app_status_bar.dart';
import 'change_password_dialog.dart';

/// Production administrative Login Screen.
/// Standalone 440px card outside AppShell, with pinned AppStatusBar.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  String? _selectedUsername;
  List<String> _usernames = [];
  bool _isLoadingUsers = true;

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  bool _isCapsLockOn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkCapsLock();
    HardwareKeyboard.instance.addHandler(_keyboardHandler);
    _loadInitialData();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyboardHandler);
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _checkCapsLock() {
    final caps = HardwareKeyboard.instance.lockModesEnabled.contains(
      KeyboardLockMode.capsLock,
    );
    if (caps != _isCapsLockOn) {
      setState(() => _isCapsLockOn = caps);
    }
  }

  bool _keyboardHandler(KeyEvent event) {
    _checkCapsLock();
    return false;
  }

  /// G-10 Shot 4: right after the setup wizard completes, the tenant
  /// database is re-provisioned asynchronously (tenant-scoped file created
  /// and the wizard's admin user inserted on the next open, raced with this
  /// screen's first query). When the first load observes an empty Users
  /// table while a tenant is configured, retry briefly before settling.
  /// Gated on a tenant actually existing so widget tests (no tenant plugin)
  /// are unaffected.
  Future<void> _loadInitialData({int attempt = 0}) async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final users = await authRepo.getAllUsernames();
      final remembered = await authRepo.getRememberedUsername();

      if (users.isEmpty && attempt < 3) {
        final tenant = ref.read(tenantProvider);
        if (tenant != null) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          await _loadInitialData(attempt: attempt + 1);
          return;
        }
      }

      if (mounted) {
        setState(() {
          _usernames = users;
          if (users.isNotEmpty) {
            if (remembered != null && users.contains(remembered)) {
              _selectedUsername = remembered;
            } else {
              _selectedUsername = users.first;
            }
          }
          _isLoadingUsers = false;
        });

        // Focus password field after initial load
        _passwordFocusNode.requestFocus();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);

    final username = _selectedUsername;
    final password = _passwordController.text;

    // 1. Validation: username not null and password not empty
    if (username == null || username.trim().isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Enter User Name / Password Please';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.authenticate(username, password);

      if (user == null) {
        // 5. Failure
        if (mounted) {
          setState(() {
            _errorMessage = 'invalid User or Password';
            _passwordController.clear();
            _isLoading = false;
          });
          _passwordFocusNode.requestFocus();
        }
        return;
      }

      // 4. Success
      // a. Remember me persistence
      await authRepo.setRememberedUsername(_rememberMe ? username : null);

      // b. Allowed object IDs
      final allowedObjIds = await authRepo.getUserAllowedObjectIds(user.id);

      // c & d. Session & Weak password warning
      final isWeak = password.length < 8;
      ref
          .read(sessionProvider.notifier)
          .setSession(user, allowedObjIds, hasWeakPasswordWarning: isWeak);

      // Fire-and-forget daily auto-backup. Never blocks login and never
      // surfaces errors to the user (logged via debugPrint only).
      unawaited(
        ref.read(backupProvider.notifier).runAutoBackupOnLaunch().catchError((
          Object e,
          StackTrace st,
        ) {
          debugPrint('Auto-backup on login failed (non-fatal): $e');
        }),
      );

      // e. Navigate to dashboard
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openChangePasswordDialog() async {
    await ChangePasswordDialog.show(context, username: _selectedUsername);
  }

  Future<void> _exitApplication() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        await windowManager.close();
      } catch (_) {
        // In tests or headless environments windowManager might throw
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadataAsync = ref.watch(shellMetadataProvider);
    final schoolName = metadataAsync.valueOrNull?.branchName.isNotEmpty == true
        ? metadataAsync.valueOrNull!.branchName
        : 'Ailyans School';

    final hasError = _errorMessage != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Expanded canvas with centered 440px card
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth < 472
                        ? constraints.maxWidth - 32
                        : 440.0;
                    return Container(
                      width: cardWidth,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.borderDefault),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16.0,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Inner padded card content
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Header Region
                            Center(
                              child: Container(
                                width: 48.0,
                                height: 48.0,
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary,
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: const Icon(
                                  Icons.school_rounded,
                                  color: AppColors.surfaceRaised,
                                  size: 26.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              schoolName,
                              style: AppTypography.h1.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'ByteWave School Automation',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const Divider(color: AppColors.borderSubtle),
                            const SizedBox(height: AppSpacing.lg),

                            // Error Banner
                            if (hasError) ...[
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                margin: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.statusErrorBg,
                                  border: Border.all(
                                    color: AppColors.statusErrorBorder,
                                  ),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Row(
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

                            // 2. Form Region: Operator Account
                            Text(
                              'Operator Account *',
                              style: AppTypography.label.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            SizedBox(
                              height: 40.0,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(_selectedUsername),
                                initialValue:
                                    _usernames.contains(_selectedUsername)
                                    ? _selectedUsername
                                    : null,
                                isDense: true,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: AppColors.textSecondary,
                                  size: 20.0,
                                ),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 8.0,
                                  ),
                                  filled: true,
                                  fillColor: _isLoading
                                      ? AppColors.surfaceSubtle
                                      : AppColors.surfaceRaised,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    borderSide: const BorderSide(
                                      color: AppColors.borderDefault,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    borderSide: const BorderSide(
                                      color: AppColors.borderDefault,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    borderSide: const BorderSide(
                                      color: AppColors.borderFocus,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                hint: Text(
                                  _isLoadingUsers
                                      ? 'Loading operators...'
                                      : 'Select Operator',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                items: _usernames.map((name) {
                                  return DropdownMenuItem<String>(
                                    value: name,
                                    child: Text(
                                      name,
                                      style: AppTypography.body.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: _isLoading
                                    ? null
                                    : (val) {
                                        setState(() {
                                          _selectedUsername = val;
                                          _errorMessage = null;
                                        });
                                      },
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Form Region: Password
                            Text(
                              'Password *',
                              style: AppTypography.label.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            SizedBox(
                              height: 40.0,
                              child: TextField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: _obscurePassword,
                                enabled: !_isLoading,
                                onSubmitted: (_) => _handleLogin(),
                                style: AppTypography.body.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter password',
                                  hintStyle: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                  filled: true,
                                  fillColor: _isLoading
                                      ? AppColors.surfaceSubtle
                                      : AppColors.surfaceRaised,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 8.0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    borderSide: BorderSide(
                                      color: hasError
                                          ? AppColors.statusErrorText
                                          : AppColors.borderDefault,
                                      width: hasError ? 1.5 : 1.0,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    borderSide: BorderSide(
                                      color: hasError
                                          ? AppColors.statusErrorText
                                          : AppColors.borderDefault,
                                      width: hasError ? 1.5 : 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    borderSide: BorderSide(
                                      color: hasError
                                          ? AppColors.statusErrorText
                                          : AppColors.borderFocus,
                                      width: 1.5,
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 18.0,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),

                            // Caps Lock warning pill
                            if (_isCapsLockOn) ...[
                              const SizedBox(height: 6.0),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.statusWarningBg,
                                  border: Border.all(
                                    color: AppColors.statusWarningBorder,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.keyboard_capslock_rounded,
                                      size: 14.0,
                                      color: AppColors.statusWarningText,
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      'Caps Lock is ON',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.statusWarningText,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: AppSpacing.sm),

                            // Remember me checkbox
                            InkWell(
                              onTap: _isLoading
                                  ? null
                                  : () {
                                      setState(
                                        () => _rememberMe = !_rememberMe,
                                      );
                                    },
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 18.0,
                                    height: 18.0,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: _isLoading
                                          ? null
                                          : (val) {
                                              setState(
                                                () =>
                                                    _rememberMe = val ?? false,
                                              );
                                            },
                                      activeColor: AppColors.brandPrimary,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      'Remember me on this device',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppSpacing.lg),

                            // Full width Sign In button
                            SizedBox(
                              height: 44.0,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brandPrimary,
                                  foregroundColor: AppColors.surfaceRaised,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                ),
                                icon: _isLoading
                                    ? const SizedBox.shrink()
                                    : const Icon(
                                        Icons.login_rounded,
                                        size: 18.0,
                                      ),
                                label: _isLoading
                                    ? const SizedBox(
                                        width: 18.0,
                                        height: 18.0,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.surfaceRaised,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        'Sign In (Enter)',
                                        style: AppTypography.label.copyWith(
                                          color: AppColors.surfaceRaised,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // Footer action links row
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                TextButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _openChangePasswordDialog,
                                  icon: const Icon(
                                    Icons.key_outlined,
                                    size: 14.0,
                                    color: AppColors.brandPrimary,
                                  ),
                                  label: Text(
                                    'Change Operator Password',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.brandPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                      vertical: 2.0,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _exitApplication,
                                  icon: const Icon(
                                    Icons.power_settings_new,
                                    size: 14.0,
                                    color: AppColors.textSecondary,
                                  ),
                                  label: Text(
                                    'Exit Application',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                      vertical: 2.0,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Card Footer Strip
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          border: Border(
                            top: BorderSide(
                              color: AppColors.borderDefault,
                              width: 1.0,
                            ),
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(AppRadius.lg),
                            bottomRight: Radius.circular(AppRadius.lg),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 12.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8.0,
                                    height: 8.0,
                                    decoration: const BoxDecoration(
                                      color: AppColors.statusSuccessText,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      'Database: SDB_Ailyans.db (Online)',
                                      style: AppTypography.monospace.copyWith(
                                        fontSize: 11.0,
                                        color: AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'SQLite Local',
                              style: AppTypography.monospace.copyWith(
                                fontSize: 11.0,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
                  },
                ),
              ),
            ),
          ),

          // 28px bottom status bar pinned
          const AppStatusBar(),
        ],
      ),
    );
  }
}
