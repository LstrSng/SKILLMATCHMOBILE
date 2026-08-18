import 'package:flutter/material.dart';

/// Shared color tokens for SkillMatch.
///
/// These centralize the hex values that were previously duplicated as
/// inline `Color(0x...)` literals across most pages. Prefer these over
/// new inline color literals so the palette stays consistent as pages
/// are touched.
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

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF6B7280);
  static const textFaint = Color(0xFF9CA3AF);

  static const border = Color(0xFFE5E7EB);
  static const borderSoft = Color(0xFFF1F5F9);
  static const surfaceMuted = Color(0xFFF9FAFB);
  static const pageBackground = Color(0xFFF7F8FB);

  static const success = Color(0xFF10B981);
  static const successBg = Color(0xFFECFDF5);
  static const danger = Color(0xFFDC2626);
  static const dangerBorder = Color(0xFFFCA5A5);
  static const dangerBg = Color(0xFFFEF2F2);
  static const warning = Color(0xFFB45309);
  static const warningBg = Color(0xFFFEF3C7);

  /// Soft floating-card shadow — used by [AppCard] and other elevated
  /// surfaces so cards read as "lifted" instead of just outlined boxes.
  static const cardShadow = BoxShadow(
    color: Color(0x0F0F172A),
    blurRadius: 24,
    offset: Offset(0, 10),
  );
}
