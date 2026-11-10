import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/tenant_provider.dart';
import '../../core/theme/app_theme_tokens.dart';

/// G-10 Shot 2: first-launch school setup wizard for the ByteWave SaaS.
/// Rendered whenever no tenant is configured (router redirects `/` here).
class SchoolSetupScreen extends ConsumerStatefulWidget {
  const SchoolSetupScreen({super.key});

  @override
  ConsumerState<SchoolSetupScreen> createState() => _SchoolSetupScreenState();
}

class _SchoolSetupScreenState extends ConsumerState<SchoolSetupScreen> {
  final TextEditingController _schoolCtrl = TextEditingController();
  final TextEditingController _adminCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _schoolCtrl.dispose();
    _adminCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _onStartSetup() async {
    final school = _schoolCtrl.text.trim();
    final admin = _adminCtrl.text.trim();
    final contact = _contactCtrl.text.trim();
    if (school.isEmpty || admin.isEmpty || contact.isEmpty) {
      setState(() {
        _error = 'All fields are required to provision your school.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    await ref
        .read(tenantProvider.notifier)
        .createTenant(schoolName: school, adminName: admin, adminContact: contact);
    if (!mounted) return;
    context.go('/dashboard');
  }

  Widget _buildFieldCard({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
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
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
          ),
        ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
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
                        child: const Icon(
                          Icons.waves,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Welcome to ByteWave School Manager',
                  textAlign: TextAlign.center,
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textPrimary,
                  ),
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
                _buildFieldCard(
                  label: 'School Name',
                  controller: _schoolCtrl,
                ),
                const SizedBox(height: 12),
                _buildFieldCard(
                  label: 'Principal / Admin Name',
                  controller: _adminCtrl,
                ),
                const SizedBox(height: 12),
                _buildFieldCard(
                  label: 'Admin Contact (Email or Phone)',
                  controller: _contactCtrl,
                  keyboardType: TextInputType.emailAddress,
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
                    onPressed: _submitting ? null : _onStartSetup,
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
                            'Start Setup',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Powered by ByteWave',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // The LinkedIn company page is surfaced as plain text;
                    // opening an external browser is a no-op by design here.
                    context.go('/setup');
                  },
                  child: const Text('www.linkedin.com/company/bytewaves'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
