import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/tenant_provider.dart';
import '../../core/theme/app_theme_tokens.dart';

/// G-10 Shot 3: two-step first-launch school setup wizard for the ByteWave
/// SaaS. Step 0 collects school details; step 1 creates the admin account.
/// Rendered whenever no tenant is configured (router redirects here).
class SchoolSetupScreen extends ConsumerStatefulWidget {
  const SchoolSetupScreen({super.key});

  @override
  ConsumerState<SchoolSetupScreen> createState() => _SchoolSetupScreenState();
}

class _SchoolSetupScreenState extends ConsumerState<SchoolSetupScreen> {
  // G-10 Shot 3: wizard step (0 = School Details, 1 = Admin Credentials).
  int _currentStep = 0;

  // Step 0: school details.
  final TextEditingController _schoolCtrl = TextEditingController();
  final TextEditingController _principalCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  // Step 1: admin credentials.
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _pinConfirmCtrl = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscurePin = true;
  String? _error;

  static final RegExp _pinPattern = RegExp(r'^\d{4,6}$');

  @override
  void dispose() {
    _schoolCtrl.dispose();
    _principalCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _pinCtrl.dispose();
    _pinConfirmCtrl.dispose();
    super.dispose();
  }

  bool _validateStep0() {
    if (_schoolCtrl.text.trim().isEmpty ||
        _principalCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty) {
      setState(() {
        _error = 'All school fields are required to continue.';
      });
      return false;
    }
    return true;
  }

  bool _validateStep1() {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final pin = _pinCtrl.text.trim();
    final pinConfirm = _pinConfirmCtrl.text.trim();
    if (username.isEmpty || password.isEmpty || pin.isEmpty) {
      setState(() {
        _error = 'All admin fields are required.';
      });
      return false;
    }
    if (password.length < 8) {
      setState(() {
        _error = 'Password must be at least 8 characters.';
      });
      return false;
    }
    if (!_pinPattern.hasMatch(pin)) {
      setState(() {
        _error = 'PIN must be 4 to 6 digits.';
      });
      return false;
    }
    if (pin != pinConfirm) {
      setState(() {
        _error = 'PIN confirmation does not match.';
      });
      return false;
    }
    return true;
  }

  Future<void> _onCreateSchool() async {
    if (!_validateStep1()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    await ref
        .read(tenantProvider.notifier)
        .createTenant(
          schoolName: _schoolCtrl.text.trim(),
          adminName: _principalCtrl.text.trim(),
          adminContact: _emailCtrl.text.trim(),
          contactPhone: _phoneCtrl.text.trim(),
          adminUsername: _usernameCtrl.text.trim(),
          adminPassword: _passwordCtrl.text,
          adminPin: _pinCtrl.text.trim(),
        );
    if (!mounted) return;
    // G-10 Shot 4: route through the license activation gate before login.
    context.go('/license');
  }

  void _onNext() {
    if (!_validateStep0()) return;
    setState(() {
      _currentStep = 1;
      _error = null;
    });
  }

  Widget _buildFieldCard({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            autocorrect: false,
            enableSuggestions: !obscureText,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              suffixIcon: suffix,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/logo_bytewave.png',
          height: 80,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.waves, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }

  Widget _buildStep0School() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLogo(),
        const SizedBox(height: 20),
        Text(
          'Welcome to ByteWave School Manager',
          textAlign: TextAlign.center,
          style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'Set up your school to get started.',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        _buildFieldCard(label: 'School Name', controller: _schoolCtrl),
        const SizedBox(height: 12),
        _buildFieldCard(
          label: 'Principal / Admin Name',
          controller: _principalCtrl,
        ),
        const SizedBox(height: 12),
        _buildFieldCard(
          label: 'Contact Email',
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _buildFieldCard(
          label: 'Contact Phone',
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.statusErrorText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 24),
        _buildPrimaryButton(label: 'Next: Admin Setup', onPressed: _onNext),
      ],
    );
  }

  Widget _buildStep1Admin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLogo(),
        const SizedBox(height: 20),
        Text(
          'Create Admin Account',
          textAlign: TextAlign.center,
          style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'You will use these credentials to log in.',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        _buildFieldCard(
          label: 'Admin Username',
          controller: _usernameCtrl,
        ),
        const SizedBox(height: 12),
        _buildFieldCard(
          label: 'Password (min 8 characters)',
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          suffix: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: AppColors.textSecondary,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 12),
        _buildFieldCard(
          label: 'Login PIN (4-6 digits)',
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          obscureText: _obscurePin,
          suffix: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _obscurePin ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _obscurePin = !_obscurePin),
          ),
        ),
        const SizedBox(height: 12),
        _buildFieldCard(
          label: 'Confirm PIN',
          controller: _pinConfirmCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.statusErrorText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _submitting ? null : _onCreateSchool,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Create School',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: _submitting
                ? null
                : () => setState(() {
                    _currentStep = 0;
                    _error = null;
                  }),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              '← Back',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _currentStep == 0
                ? _buildStep0School()
                : _buildStep1Admin(),
          ),
        ),
      ),
    );
  }
}
