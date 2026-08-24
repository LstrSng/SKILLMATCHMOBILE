import 'package:flutter/material.dart';

import '../pages/settings_page.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'notification_bell_button.dart';

/// The standard SkillMatch top bar: brand mark + title, with settings and notifications.
/// Adapts seamlessly to Light and Dark mode themes.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title = 'SkillMatch',
    this.showSettings = true,
    this.showNotifications = true,
    this.actions,
  });

  final String title;
  final bool showSettings;
  final bool showNotifications;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: tokens.cardBackground,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: tokens.cardBorderSoft,
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: tokens.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: tokens.primary.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.bolt, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        ...?actions,
        if (showNotifications) ...[
          const NotificationBellButton(),
          const SizedBox(width: 4),
        ],
        if (showSettings)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.cardBorderSoft),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  size: 19,
                  color: tokens.textSecondary,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
          ),
      ],
    );
  }
}
