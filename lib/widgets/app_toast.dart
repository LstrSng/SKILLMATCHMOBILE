import 'package:flutter/material.dart';

import 'package:skillmatch/theme/app_colors.dart';

enum AppToastType { success, info, error }

/// A floating, rounded, light-card pop-up notification with a colored
/// icon badge — replaces the plain default `SnackBar` (dark bar, no
/// icon, docked to the screen edge) used elsewhere in the app.
void showAppToast(
  BuildContext context,
  String message, {
  AppToastType type = AppToastType.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  late final Color accent;
  late final IconData icon;
  switch (type) {
    case AppToastType.success:
      accent = AppColors.success;
      icon = Icons.check_circle;
      break;
    case AppToastType.error:
      accent = AppColors.danger;
      icon = Icons.error_outline;
      break;
    case AppToastType.info:
      accent = AppColors.primary;
      icon = Icons.info_outline;
      break;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        elevation: 4,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderSoft),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.textPrimary,
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
