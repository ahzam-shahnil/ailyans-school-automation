import 'package:flutter/material.dart';

/// Semantic Design Tokens for Ailyans School Management System.
/// Generated for Flutter Desktop Rebuild.
/// Tokens derived from 06-design-system.md Section 7.

abstract class AppColors {
  // Brand Colors (Light)
  static const Color brandPrimary = Color(0xFF1E3A8A);
  static const Color brandPrimaryHover = Color(0xFF1E40AF);
  static const Color brandPrimaryPressed = Color(0xFF172554);
  static const Color brandSecondary = Color(0xFF0D9488);
  static const Color brandSecondaryHover = Color(0xFF0F766E);
  static const Color brandSecondaryPressed = Color(0xFF115E59);

  // Surfaces (Light)
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceRaised = Color(0xFFFFFFFF);
  static const Color surfaceOverlay = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F5F9);

  // Borders (Light)
  static const Color borderDefault = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFF1F5F9);
  static const Color borderFocus = Color(0xFF2563EB);
  static const Color borderHover = Color(0xFFCBD5E1);

  // Text Colors (Light)
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);

  // Status & Feedback (Light)
  static const Color statusSuccessBg = Color(0xFFECFDF5);
  static const Color statusSuccessText = Color(0xFF047857);
  static const Color statusSuccessBorder = Color(0xFFA7F3D0);

  static const Color statusWarningBg = Color(0xFFFFFBEB);
  static const Color statusWarningText = Color(0xFFB45309);
  static const Color statusWarningBorder = Color(0xFFFDE68A);

  static const Color statusErrorBg = Color(0xFFFEF2F2);
  static const Color statusErrorText = Color(0xFFB91C1C);
  static const Color statusErrorBorder = Color(0xFFFECACA);

  static const Color statusInfoBg = Color(0xFFEFF6FF);
  static const Color statusInfoText = Color(0xFF1D4ED8);
  static const Color statusInfoBorder = Color(0xFFBFDBFE);

  // Focus Ring
  static const Color focusRing = Color(0xFF2563EB);

  // Data Visualization (8-Color Palette)
  static const Color chartBlue = Color(0xFF2563EB);
  static const Color chartTeal = Color(0xFF0D9488);
  static const Color chartAmber = Color(0xFFD97706);
  static const Color chartViolet = Color(0xFF7C3AED);
  static const Color chartRose = Color(0xFFE11D48);
  static const Color chartEmerald = Color(0xFF059669);
  static const Color chartCyan = Color(0xFF0891B2);
  static const Color chartIndigo = Color(0xFF4F46E5);

  // Mobile Canvas
  static const Color surfaceCanvas = Color(0xFFF1F5F9);

  // Status Neutral
  static const Color statusNeutralBg = Color(0xFFF1F5F9);
  static const Color statusNeutralBorder = Color(0xFFE2E8F0);
  static const Color statusNeutralText = Color(0xFF475569);

  // Module Accent Pairs
  static const Color accentDashboard = Color(0xFF1E3A8A);
  static const Color accentDashboardSoftBg = Color(0xFFEFF6FF);

  static const Color accentStudents = Color(0xFF0891B2);
  static const Color accentStudentsSoftBg = Color(0xFFECFEFF);

  static const Color accentFees = Color(0xFF059669);
  static const Color accentFeesSoftBg = Color(0xFFECFDF5);

  static const Color accentAttendance = Color(0xFFD97706);
  static const Color accentAttendanceSoftBg = Color(0xFFFFFBEB);

  static const Color accentExams = Color(0xFF7C3AED);
  static const Color accentExamsSoftBg = Color(0xFFF5F3FF);

  static const Color accentStaff = Color(0xFF0D9488);
  static const Color accentStaffSoftBg = Color(0xFFF0FDFA);

  static const Color accentLibrary = Color(0xFF4F46E5);
  static const Color accentLibrarySoftBg = Color(0xFFEEF2FF);
}

abstract class AppDarkColors {
  // Brand Colors (Dark)
  static const Color brandPrimary = Color(0xFF60A5FA);
  static const Color brandPrimaryHover = Color(0xFF93C5FD);
  static const Color brandPrimaryPressed = Color(0xFF3B82F6);
  static const Color brandSecondary = Color(0xFF2DD4BF);
  static const Color brandSecondaryHover = Color(0xFF5EEAD4);
  static const Color brandSecondaryPressed = Color(0xFF14B8A6);

  // Surfaces (Dark)
  static const Color surface = Color(0xFF0F172A);
  static const Color surfaceRaised = Color(0xFF1E293B);
  static const Color surfaceOverlay = Color(0xFF1E293B);
  static const Color surfaceSubtle = Color(0xFF182234);

  // Borders (Dark)
  static const Color borderDefault = Color(0xFF334155);
  static const Color borderSubtle = Color(0xFF1E293B);
  static const Color borderFocus = Color(0xFF60A5FA);
  static const Color borderHover = Color(0xFF475569);

  // Text Colors (Dark)
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);
  static const Color textOnPrimary = Color(0xFF0F172A);
  static const Color textOnSecondary = Color(0xFF0F172A);

  // Status & Feedback (Dark)
  static const Color statusSuccessBg = Color(0xFF064E3B);
  static const Color statusSuccessText = Color(0xFF34D399);
  static const Color statusSuccessBorder = Color(0xFF065F46);

  static const Color statusWarningBg = Color(0xFF78350F);
  static const Color statusWarningText = Color(0xFFFBBF24);
  static const Color statusWarningBorder = Color(0xFF92400E);

  static const Color statusErrorBg = Color(0xFF7F1D1D);
  static const Color statusErrorText = Color(0xFFF87171);
  static const Color statusErrorBorder = Color(0xFF991B1B);

  static const Color statusInfoBg = Color(0xFF1E3A8A);
  static const Color statusInfoText = Color(0xFF60A5FA);
  static const Color statusInfoBorder = Color(0xFF2563EB);

  // Focus Ring
  static const Color focusRing = Color(0xFF60A5FA);

  // Data Visualization (8-Color Palette Dark)
  static const Color chartBlue = Color(0xFF60A5FA);
  static const Color chartTeal = Color(0xFF2DD4BF);
  static const Color chartAmber = Color(0xFFFBBF24);
  static const Color chartViolet = Color(0xFFA78BFA);
  static const Color chartRose = Color(0xFFFB7185);
  static const Color chartEmerald = Color(0xFF34D399);
  static const Color chartCyan = Color(0xFF38BDF8);
  static const Color chartIndigo = Color(0xFF818CF8);

  // Mobile Canvas (Dark)
  static const Color surfaceCanvas = Color(0xFF090D16);

  // Status Neutral (Dark)
  static const Color statusNeutralBg = Color(0xFF1E293B);
  static const Color statusNeutralBorder = Color(0xFF334155);
  static const Color statusNeutralText = Color(0xFF94A3B8);

  // Module Accent Pairs (Dark)
  static const Color accentDashboard = Color(0xFF60A5FA);
  static const Color accentDashboardSoftBg = Color(0xFF1E293B);

  static const Color accentStudents = Color(0xFF38BDF8);
  static const Color accentStudentsSoftBg = Color(0xFF164E63);

  static const Color accentFees = Color(0xFF34D399);
  static const Color accentFeesSoftBg = Color(0xFF064E3B);

  static const Color accentAttendance = Color(0xFFFBBF24);
  static const Color accentAttendanceSoftBg = Color(0xFF78350F);

  static const Color accentExams = Color(0xFFA78BFA);
  static const Color accentExamsSoftBg = Color(0xFF4C1D95);

  static const Color accentStaff = Color(0xFF2DD4BF);
  static const Color accentStaffSoftBg = Color(0xFF134E4A);

  static const Color accentLibrary = Color(0xFF818CF8);
  static const Color accentLibrarySoftBg = Color(0xFF312E81);
}

abstract class AppStatusPill {
  // Light variants
  static const readyBg = Color(0xFFDCFCE7);
  static const readyText = Color(0xFF14532D);
  static const readyBorder = Color(0xFF86EFAC);

  static const generatedBg = Color(0xFFDBEAFE);
  static const generatedText = Color(0xFF1E3A8A);
  static const generatedBorder = Color(0xFF93C5FD);

  static const rolloverBg = Color(0xFFFEF3C7);
  static const rolloverText = Color(0xFF78350F);
  static const rolloverBorder = Color(0xFFFCD34D);

  static const waiverBg = Color(0xFFF1F5F9);
  static const waiverText = Color(0xFF334155);
  static const waiverBorder = Color(0xFFCBD5E1);
  // Note: add dark variants later or use existing tokens.
}

abstract class AppSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double huge = 64.0;
}

abstract class AppRadius {
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 9999.0;
}

abstract class AppElevation {
  static const double flat = 0.0;
  static const double raised = 1.0;
  static const double modal = 4.0;
  static const double popover = 8.0;
}

abstract class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

abstract class AppTypography {
  static const TextStyle display = TextStyle(
    fontFamily: 'Inter',
    fontSize: 32.0,
    fontWeight: FontWeight.w700,
    height: 40.0 / 32.0,
    letterSpacing: -0.5,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    height: 32.0 / 24.0,
    letterSpacing: -0.25,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    height: 24.0 / 18.0,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    height: 20.0 / 15.0,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    height: 20.0 / 14.0,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    height: 16.0 / 12.0,
    letterSpacing: 0.1,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13.0,
    fontWeight: FontWeight.w600,
    height: 16.0 / 13.0,
    letterSpacing: 0.2,
  );

  static const TextStyle monospace = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
    height: 18.0 / 13.0,
  );
}

/// Light ThemeData wired with semantic design tokens.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: AppColors.brandPrimary,
    onPrimary: AppColors.textOnPrimary,
    secondary: AppColors.brandSecondary,
    onSecondary: AppColors.textOnSecondary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.statusErrorText,
    onError: AppColors.surfaceRaised,
    outline: AppColors.borderDefault,
    outlineVariant: AppColors.borderSubtle,
  ),
  scaffoldBackgroundColor: AppColors.surface,
  cardColor: AppColors.surfaceRaised,
  cardTheme: CardThemeData(
    color: AppColors.surfaceRaised,
    elevation: AppElevation.raised,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: const BorderSide(color: AppColors.borderDefault, width: 1.0),
    ),
    margin: EdgeInsets.zero,
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.borderDefault,
    thickness: 1.0,
    space: 1.0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceRaised,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.sm,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.borderDefault),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.borderDefault),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.borderFocus, width: 2.0),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.statusErrorText),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(
        color: AppColors.statusErrorText,
        width: 2.0,
      ),
    ),
    hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
    labelStyle: AppTypography.label.copyWith(color: AppColors.textSecondary),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.brandPrimary,
      foregroundColor: AppColors.textOnPrimary,
      elevation: AppElevation.flat,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: AppTypography.label,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      side: const BorderSide(color: AppColors.borderDefault),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: AppTypography.label,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.brandPrimary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: AppTypography.label,
    ),
  ),
  textTheme: TextTheme(
    displayLarge: AppTypography.display.copyWith(color: AppColors.textPrimary),
    headlineMedium: AppTypography.h1.copyWith(color: AppColors.textPrimary),
    titleLarge: AppTypography.h2.copyWith(color: AppColors.textPrimary),
    titleMedium: AppTypography.h3.copyWith(color: AppColors.textPrimary),
    bodyLarge: AppTypography.body.copyWith(color: AppColors.textPrimary),
    bodyMedium: AppTypography.body.copyWith(color: AppColors.textPrimary),
    bodySmall: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
    labelLarge: AppTypography.label.copyWith(color: AppColors.textPrimary),
  ),
);

/// Dark ThemeData wired with semantic design tokens.
final ThemeData appDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: AppDarkColors.brandPrimary,
    onPrimary: AppDarkColors.textOnPrimary,
    secondary: AppDarkColors.brandSecondary,
    onSecondary: AppDarkColors.textOnSecondary,
    surface: AppDarkColors.surface,
    onSurface: AppDarkColors.textPrimary,
    error: AppDarkColors.statusErrorText,
    onError: AppDarkColors.surfaceRaised,
    outline: AppDarkColors.borderDefault,
    outlineVariant: AppDarkColors.borderSubtle,
  ),
  scaffoldBackgroundColor: AppDarkColors.surface,
  cardColor: AppDarkColors.surfaceRaised,
  cardTheme: CardThemeData(
    color: AppDarkColors.surfaceRaised,
    elevation: AppElevation.raised,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: const BorderSide(color: AppDarkColors.borderDefault, width: 1.0),
    ),
    margin: EdgeInsets.zero,
  ),
  dividerTheme: const DividerThemeData(
    color: AppDarkColors.borderDefault,
    thickness: 1.0,
    space: 1.0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppDarkColors.surfaceRaised,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.sm,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppDarkColors.borderDefault),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppDarkColors.borderDefault),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(
        color: AppDarkColors.borderFocus,
        width: 2.0,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppDarkColors.statusErrorText),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(
        color: AppDarkColors.statusErrorText,
        width: 2.0,
      ),
    ),
    hintStyle: AppTypography.body.copyWith(color: AppDarkColors.textMuted),
    labelStyle: AppTypography.label.copyWith(
      color: AppDarkColors.textSecondary,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppDarkColors.brandPrimary,
      foregroundColor: AppDarkColors.textOnPrimary,
      elevation: AppElevation.flat,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: AppTypography.label,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppDarkColors.textPrimary,
      side: const BorderSide(color: AppDarkColors.borderDefault),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: AppTypography.label,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppDarkColors.brandPrimary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: AppTypography.label,
    ),
  ),
  textTheme: TextTheme(
    displayLarge: AppTypography.display.copyWith(
      color: AppDarkColors.textPrimary,
    ),
    headlineMedium: AppTypography.h1.copyWith(color: AppDarkColors.textPrimary),
    titleLarge: AppTypography.h2.copyWith(color: AppDarkColors.textPrimary),
    titleMedium: AppTypography.h3.copyWith(color: AppDarkColors.textPrimary),
    bodyLarge: AppTypography.body.copyWith(color: AppDarkColors.textPrimary),
    bodyMedium: AppTypography.body.copyWith(color: AppDarkColors.textPrimary),
    bodySmall: AppTypography.bodySmall.copyWith(
      color: AppDarkColors.textSecondary,
    ),
    labelLarge: AppTypography.label.copyWith(color: AppDarkColors.textPrimary),
  ),
);
