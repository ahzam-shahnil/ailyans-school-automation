import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/build_config.dart';
import '../../core/providers/license_provider.dart';
import '../../core/theme/app_theme_tokens.dart';

/// G-10 Shot 4: SaaS license activation gate, shown between the setup wizard
/// and the login screen. Validates the entered key via [licenseProvider]
/// (trial-key fallback until the Supabase RPC is wired).
class LicenseEntryScreen extends ConsumerStatefulWidget {
  const LicenseEntryScreen({super.key});

  @override
  ConsumerState<LicenseEntryScreen> createState() =>
      _LicenseEntryScreenState();
}

class _LicenseEntryScreenState extends ConsumerState<LicenseEntryScreen> {
  final TextEditingController _keyCtrl = TextEditingController();
  bool _isValidating = false;
  String? _error;

  static const _contactUrl = 'https://www.linkedin.com/company/bytewaves';

  @override
  void initState() {
    super.initState();
    // Ailyans Edition ships with the launch trial key pre-filled so the
    // onboarding flow can be bypassed quickly during testing.
    if (BuildConfig.isAilyansEdition) {
      _keyCtrl.text = LicenseNotifier.trialKey;
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _onActivate() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() {
        _error = 'Please enter a license key.';
      });
      return;
    }
    setState(() {
      _isValidating = true;
      _error = null;
    });
    final ok = await ref
        .read(licenseProvider.notifier)
        .validateAndStore(key);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _isValidating = false;
        _error = 'Invalid or expired license key. Please try again.';
      });
      return;
    }
    context.go('/login');
  }

  void _onContactByteWave() {
    // url_launcher is not part of the locked Shot 4 dependency set; surface
    // the link through a SnackBar instead. TODO: swap for launchUrl once
    // url_launcher is added to pubspec.yaml.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact ByteWave: $_contactUrl'),
        backgroundColor: AppColors.brandPrimary,
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
                _buildLogo(),
                const SizedBox(height: 20),
                Text(
                  'Activate Your License',
                  textAlign: TextAlign.center,
                  style: AppTypography.h1.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the license key provided by ByteWave to activate '
                  'your school.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
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
                        'License Key',
                        style: AppTypography.label.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _keyCtrl,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: AppTypography.monospace.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'XXXX-XXXX-XXXX-XXXX',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusErrorBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.statusErrorText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isValidating ? null : _onActivate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: _isValidating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Activate',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isValidating ? null : _onContactByteWave,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text(
                    "Don't have a key? Contact ByteWave",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
