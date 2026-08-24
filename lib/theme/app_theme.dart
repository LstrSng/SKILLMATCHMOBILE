import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:skillmatch/theme/app_colors.dart';

/// Central Material 3 Theme configuration for SkillMatch+.
/// Supports full Light & Dark mode parity with responsive typography,
/// adaptive component styles, and [AppThemeExtension] token integration.
ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final ext = isDark ? AppThemeExtension.dark() : AppThemeExtension.light();

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
    primary: isDark ? AppColors.primaryLight : AppColors.primary,
    onPrimary: isDark ? const Color(0xFF0F172A) : Colors.white,
    secondary: isDark ? AppColors.accentLight : AppColors.accent,
    surface: isDark ? AppColors.darkCardBackground : Colors.white,
    onSurface: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
    error: isDark ? AppColors.dangerLight : AppColors.danger,
    outline: isDark ? AppColors.darkBorder : AppColors.border,
    outlineVariant: isDark ? AppColors.darkBorderSoft : AppColors.borderSoft,
  );

  const radius = 12.0;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  final textFaint = isDark ? AppColors.darkTextFaint : AppColors.textFaint;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
    cardColor: isDark ? AppColors.darkCardBackground : Colors.white,
    canvasColor: isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
    ),
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    fontFamily: 'Roboto',
    extensions: [ext],

    // -------------------------------------------------------------------------
    // Responsive Typography Scale with calibrated tracking & line heights
    // -------------------------------------------------------------------------
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: -1.0,
        height: 1.12,
      ),
      displayMedium: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: -0.8,
        height: 1.15,
      ),
      displaySmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: -0.6,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.4,
        height: 1.25,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.2,
        height: 1.35,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.1,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.0,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        letterSpacing: 0.1,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        letterSpacing: 0.1,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        letterSpacing: 0.2,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.1,
        height: 1.2,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        letterSpacing: 0.2,
        height: 1.2,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: textFaint,
        letterSpacing: 0.4,
        height: 1.2,
      ),
    ),

    // -------------------------------------------------------------------------
    // App Bar Theme
    // -------------------------------------------------------------------------
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: textPrimary, size: 22),
    ),

    // -------------------------------------------------------------------------
    // Card Theme
    // -------------------------------------------------------------------------
    cardTheme: CardThemeData(
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.borderSoft),
      ),
    ),

    // -------------------------------------------------------------------------
    // Buttons
    // -------------------------------------------------------------------------
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: shape,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: shape,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: shape,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    // -------------------------------------------------------------------------
    // Inputs & Forms
    // -------------------------------------------------------------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted,
      hintStyle: TextStyle(color: textFaint, fontSize: 14),
      labelStyle: TextStyle(color: textSecondary, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: isDark ? AppColors.darkBorder : AppColors.border,
      thickness: 1,
      space: 1,
    ),

    // -------------------------------------------------------------------------
    // Interactive Controls
    // -------------------------------------------------------------------------
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : (isDark ? Colors.grey[400] : Colors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : (isDark ? AppColors.darkBorder : AppColors.border),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.transparent,
      ),
      side: BorderSide(color: textFaint, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: isDark ? AppColors.primaryLight : AppColors.primary,
      linearTrackColor: isDark ? AppColors.darkBorder : AppColors.border,
      circularTrackColor: isDark ? AppColors.darkBorder : AppColors.border,
    ),

    iconTheme: IconThemeData(color: textSecondary, size: 22),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
      selectedItemColor: isDark ? AppColors.primaryLight : AppColors.primary,
      unselectedItemColor: textFaint,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Convenience shortcuts for Light and Dark themes.
ThemeData buildLightTheme() => buildAppTheme(brightness: Brightness.light);
ThemeData buildDarkTheme() => buildAppTheme(brightness: Brightness.dark);
