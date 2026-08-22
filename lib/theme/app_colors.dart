import 'package:flutter/material.dart';

/// Shared color tokens for SkillMatch.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFF60A5FA);
  static const primarySoftBg = Color(0xFFEFF6FF);
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF1D4ED8)],
  );

  static const accent = Color(0xFF8B5CF6);
  static const accentSoft = Color(0xFFF5F3FF);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF6B7280);
  static const textFaint = Color(0xFF9CA3AF);

  static const border = Color(0xFFE5E7EB);
  static const borderSoft = Color(0xFFF1F5F9);
  static const surfaceMuted = Color(0xFFF9FAFB);
  static const pageBackground = Color(0xFFF8FAFC);

  static const success = Color(0xFF10B981);
  static const successBg = Color(0xFFECFDF5);
  static const danger = Color(0xFFDC2626);
  static const dangerBorder = Color(0xFFFCA5A5);
  static const dangerBg = Color(0xFFFEF2F2);
  static const warning = Color(0xFFB45309);
  static const warningBg = Color(0xFFFEF3C7);

  // Match score color helpers
  static const badgeHighMatch = Color(0xFF059669);
  static const badgeHighMatchBg = Color(0xFFD1FAE5);
  static const badgeMedMatch = Color(0xFF2563EB);
  static const badgeMedMatchBg = Color(0xFFDBEAFE);
  static const badgeLowMatch = Color(0xFFD97706);
  static const badgeLowMatchBg = Color(0xFFFEF3C7);

  static Color matchColor(int percentage) {
    if (percentage >= 80) return badgeHighMatch;
    if (percentage >= 60) return badgeMedMatch;
    return badgeLowMatch;
  }

  static Color matchBgColor(int percentage) {
    if (percentage >= 80) return badgeHighMatchBg;
    if (percentage >= 60) return badgeMedMatchBg;
    return badgeLowMatchBg;
  }

  /// Soft floating-card shadow — used by [AppCard] and other elevated
  /// surfaces so cards read as "lifted" instead of just outlined boxes.
  static const cardShadow = BoxShadow(
    color: Color(0x0C0F172A),
    blurRadius: 18,
    offset: Offset(0, 4),
  );

  static const subtleShadow = BoxShadow(
    color: Color(0x08000000),
    blurRadius: 12,
    offset: Offset(0, 2),
  );
}
