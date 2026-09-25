import 'package:flutter/material.dart';

/// Comprehensive design token hierarchy for SkillMatch+.
/// Supports both static access for backward compatibility and reactive
/// contextual theme extension access for Light & Dark mode parity.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Brand Tokens
  // ---------------------------------------------------------------------------
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFF60A5FA);
  static const primarySoftBg = Color(0xFFEFF6FF);
  static const primaryDarkSoftBg = Color(0xFF172554);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF1D4ED8)],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );

  static const accent = Color(0xFF8B5CF6);
  static const accentDark = Color(0xFF7C3AED);
  static const accentLight = Color(0xFFA78BFA);
  static const accentSoft = Color(0xFFF5F3FF);
  static const accentDarkSoft = Color(0xFF2E1065);

  static const verified = Color(0xFF6366F1);
  static const verifiedDark = Color(0xFF818CF8);
  static const verifiedSoft = Color(0xFFEEF2FF);
  static const verifiedDarkSoft = Color(0xFF312E81);

  // ---------------------------------------------------------------------------
  // Semantic Colors
  // ---------------------------------------------------------------------------
  static const success = Color(0xFF10B981);
  static const successDark = Color(0xFF059669);
  static const successLight = Color(0xFF34D399);
  static const successBg = Color(0xFFECFDF5);
  static const successDarkBg = Color(0xFF064E3B);
  static const successBorder = Color(0xFFA7F3D0);

  static const danger = Color(0xFFDC2626);
  static const dangerDark = Color(0xFFB91C1C);
  static const dangerLight = Color(0xFFF87171);
  static const dangerBorder = Color(0xFFFCA5A5);
  static const dangerBg = Color(0xFFFEF2F2);
  static const dangerDarkBg = Color(0xFF7F1D1D);

  static const warning = Color(0xFFD97706);
  static const warningDark = Color(0xFFB45309);
  static const warningLight = Color(0xFFFBBF24);
  static const warningBg = Color(0xFFFEF3C7);
  static const warningDarkBg = Color(0xFF78350F);
  static const warningBorder = Color(0xFFFDE68A);

  static const info = Color(0xFF0284C7);
  static const infoLight = Color(0xFF38BDF8);
  static const infoBg = Color(0xFFF0F9FF);
  static const infoDarkBg = Color(0xFF0C4A6E);
  static const infoBorder = Color(0xFFBAE6FD);

  // ---------------------------------------------------------------------------
  // Light Mode Surfaces & Text
  // ---------------------------------------------------------------------------
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textFaint = Color(0xFF475569);
  static const textDisabled = Color(0xFF94A3B8);

  static const border = Color(0xFFE2E8F0);
  static const borderSoft = Color(0xFFF1F5F9);
  static const surfaceMuted = Color(0xFFF8FAFC);
  static const pageBackground = Color(0xFFF8FAFC);
  static const cardBackground = Colors.white;

  // ---------------------------------------------------------------------------
  // Dark Mode Surfaces & Text
  // ---------------------------------------------------------------------------
  static const darkPageBackground = Color(0xFF0B0F19);
  static const darkCardBackground = Color(0xFF151E2E);
  static const darkSurfaceMuted = Color(0xFF1E293B);
  static const darkSurfaceElevated = Color(0xFF243044);
  static const darkBorder = Color(0xFF334155);
  static const darkBorderSoft = Color(0xFF1E293B);

  static const darkTextPrimary = Color(0xFFF8FAFC);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkTextFaint = Color(0xFF64748B);

  // ---------------------------------------------------------------------------
  // Match Score Color Tokens
  // ---------------------------------------------------------------------------
  static const badgeHighMatch = Color(0xFF059669);
  static const badgeHighMatchBg = Color(0xFFD1FAE5);
  static const badgeHighMatchDark = Color(0xFF34D399);
  static const badgeHighMatchDarkBg = Color(0xFF064E3B);

  static const badgeMedMatch = Color(0xFF2563EB);
  static const badgeMedMatchBg = Color(0xFFDBEAFE);
  static const badgeMedMatchDark = Color(0xFF60A5FA);
  static const badgeMedMatchDarkBg = Color(0xFF1E3A8A);

  static const badgeLowMatch = Color(0xFFD97706);
  static const badgeLowMatchBg = Color(0xFFFEF3C7);
  static const badgeLowMatchDark = Color(0xFFFBBF24);
  static const badgeLowMatchDarkBg = Color(0xFF78350F);

  static const badgeGapMatch = Color(0xFFDC2626);
  static const badgeGapMatchBg = Color(0xFFFEF2F2);
  static const badgeGapMatchDark = Color(0xFFF87171);
  static const badgeGapMatchDarkBg = Color(0xFF7F1D1D);

  static Color matchColor(int percentage, {bool isDark = false}) {
    if (percentage >= 85) return isDark ? badgeHighMatchDark : badgeHighMatch;
    if (percentage >= 70) return isDark ? badgeMedMatchDark : badgeMedMatch;
    if (percentage >= 50) return isDark ? badgeLowMatchDark : badgeLowMatch;
    return isDark ? badgeGapMatchDark : badgeGapMatch;
  }

  static Color matchBgColor(int percentage, {bool isDark = false}) {
    if (percentage >= 85) {
      return isDark ? badgeHighMatchDarkBg : badgeHighMatchBg;
    }
    if (percentage >= 70) return isDark ? badgeMedMatchDarkBg : badgeMedMatchBg;
    if (percentage >= 50) return isDark ? badgeLowMatchDarkBg : badgeLowMatchBg;
    return isDark ? badgeGapMatchDarkBg : badgeGapMatchBg;
  }

  static Color matchBorderColor(int percentage, {bool isDark = false}) {
    if (percentage >= 85) {
      return isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0);
    }
    if (percentage >= 70) {
      return isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE);
    }
    if (percentage >= 50) {
      return isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A);
    }
    return isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA);
  }

  // ---------------------------------------------------------------------------
  // Ambient Elevation Shadows
  // ---------------------------------------------------------------------------
  /// Ambient floating-card shadow (Light mode): dual-layer softness.
  static const cardShadow = BoxShadow(
    color: Color(0x0A0F172A),
    blurRadius: 16,
    offset: Offset(0, 4),
  );

  static const cardShadowsLight = [
    BoxShadow(color: Color(0x080F172A), blurRadius: 20, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const cardShadowsDark = [
    BoxShadow(color: Color(0x3D000000), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const subtleShadow = BoxShadow(
    color: Color(0x08000000),
    blurRadius: 12,
    offset: Offset(0, 2),
  );

  static BoxShadow glow(
    Color color, {
    double blur = 14,
    double spread = 0,
    double opacity = 0.25,
  }) {
    return BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: blur,
      spreadRadius: spread,
      offset: const Offset(0, 4),
    );
  }
}

/// ThemeExtension that provides contextual color tokens matching the active brightness.
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.scaffoldBackground,
    required this.cardBackground,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.cardBorder,
    required this.cardBorderSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.primary,
    required this.primarySoftBg,
    required this.primaryGradient,
    required this.accent,
    required this.accentSoft,
    required this.verified,
    required this.verifiedSoft,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.danger,
    required this.dangerBg,
    required this.info,
    required this.infoBg,
    required this.cardShadows,
    required this.isDark,
  });

  final Color scaffoldBackground;
  final Color cardBackground;
  final Color surfaceMuted;
  final Color surfaceElevated;
  final Color cardBorder;
  final Color cardBorderSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;
  final Color primary;
  final Color primarySoftBg;
  final LinearGradient primaryGradient;
  final Color accent;
  final Color accentSoft;
  final Color verified;
  final Color verifiedSoft;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color danger;
  final Color dangerBg;
  final Color info;
  final Color infoBg;
  final List<BoxShadow> cardShadows;
  final bool isDark;

  factory AppThemeExtension.light() {
    return const AppThemeExtension(
      scaffoldBackground: AppColors.pageBackground,
      cardBackground: AppColors.cardBackground,
      surfaceMuted: AppColors.surfaceMuted,
      surfaceElevated: Colors.white,
      cardBorder: AppColors.border,
      cardBorderSoft: AppColors.borderSoft,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textFaint: AppColors.textFaint,
      primary: AppColors.primary,
      primarySoftBg: AppColors.primarySoftBg,
      primaryGradient: AppColors.primaryGradient,
      accent: AppColors.accent,
      accentSoft: AppColors.accentSoft,
      verified: AppColors.verified,
      verifiedSoft: AppColors.verifiedSoft,
      success: AppColors.success,
      successBg: AppColors.successBg,
      warning: AppColors.warning,
      warningBg: AppColors.warningBg,
      danger: AppColors.danger,
      dangerBg: AppColors.dangerBg,
      info: AppColors.info,
      infoBg: AppColors.infoBg,
      cardShadows: AppColors.cardShadowsLight,
      isDark: false,
    );
  }

  factory AppThemeExtension.dark() {
    return const AppThemeExtension(
      scaffoldBackground: AppColors.darkPageBackground,
      cardBackground: AppColors.darkCardBackground,
      surfaceMuted: AppColors.darkSurfaceMuted,
      surfaceElevated: AppColors.darkSurfaceElevated,
      cardBorder: AppColors.darkBorder,
      cardBorderSoft: AppColors.darkBorderSoft,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      textFaint: AppColors.darkTextFaint,
      primary: AppColors.primaryLight,
      primarySoftBg: AppColors.primaryDarkSoftBg,
      primaryGradient: AppColors.primaryGradient,
      accent: AppColors.accentLight,
      accentSoft: AppColors.accentDarkSoft,
      verified: AppColors.verifiedDark,
      verifiedSoft: AppColors.verifiedDarkSoft,
      success: AppColors.successLight,
      successBg: AppColors.successDarkBg,
      warning: AppColors.warningLight,
      warningBg: AppColors.warningDarkBg,
      danger: AppColors.dangerLight,
      dangerBg: AppColors.dangerDarkBg,
      info: AppColors.infoLight,
      infoBg: AppColors.infoDarkBg,
      cardShadows: AppColors.cardShadowsDark,
      isDark: true,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    Color? scaffoldBackground,
    Color? cardBackground,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? cardBorder,
    Color? cardBorderSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? primary,
    Color? primarySoftBg,
    LinearGradient? primaryGradient,
    Color? accent,
    Color? accentSoft,
    Color? verified,
    Color? verifiedSoft,
    Color? success,
    Color? successBg,
    Color? warning,
    Color? warningBg,
    Color? danger,
    Color? dangerBg,
    Color? info,
    Color? infoBg,
    List<BoxShadow>? cardShadows,
    bool? isDark,
  }) {
    return AppThemeExtension(
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      cardBorder: cardBorder ?? this.cardBorder,
      cardBorderSoft: cardBorderSoft ?? this.cardBorderSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textFaint: textFaint ?? this.textFaint,
      primary: primary ?? this.primary,
      primarySoftBg: primarySoftBg ?? this.primarySoftBg,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      verified: verified ?? this.verified,
      verifiedSoft: verifiedSoft ?? this.verifiedSoft,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      info: info ?? this.info,
      infoBg: infoBg ?? this.infoBg,
      cardShadows: cardShadows ?? this.cardShadows,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      scaffoldBackground: Color.lerp(
        scaffoldBackground,
        other.scaffoldBackground,
        t,
      )!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardBorderSoft: Color.lerp(cardBorderSoft, other.cardBorderSoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoftBg: Color.lerp(primarySoftBg, other.primarySoftBg, t)!,
      primaryGradient: LinearGradient.lerp(
        primaryGradient,
        other.primaryGradient,
        t,
      )!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      verified: Color.lerp(verified, other.verified, t)!,
      verifiedSoft: Color.lerp(verifiedSoft, other.verifiedSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      cardShadows: other.cardShadows,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Convenience getter for `AppThemeExtension` on `BuildContext`.
extension AppThemeContextExtension on BuildContext {
  AppThemeExtension get appColors =>
      Theme.of(this).extension<AppThemeExtension>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppThemeExtension.dark()
          : AppThemeExtension.light());

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
