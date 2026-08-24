import 'package:flutter/material.dart';

import 'package:skillmatch/theme/app_colors.dart';

enum AppToastType { success, info, error, warning }

/// A floating, rounded, elevated toast notification with an icon badge.
/// Automatically adapts colors and contrast to Light & Dark themes.
void showAppToast(
  BuildContext context,
  String message, {
  AppToastType type = AppToastType.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final tokens = context.appColors;
  final isDark = context.isDarkMode;

  late final Color accent;
  late final IconData icon;
  switch (type) {
    case AppToastType.success:
      accent = tokens.success;
      icon = Icons.check_circle_rounded;
      break;
    case AppToastType.error:
      accent = tokens.danger;
      icon = Icons.error_outline_rounded;
      break;
    case AppToastType.warning:
      accent = tokens.warning;
      icon = Icons.warning_amber_rounded;
      break;
    case AppToastType.info:
      accent = tokens.primary;
      icon = Icons.info_outline_rounded;
      break;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.cardBackground,
        elevation: 4,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: tokens.cardBorderSoft),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: accent,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
}
