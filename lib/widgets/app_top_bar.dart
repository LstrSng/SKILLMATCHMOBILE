import 'package:flutter/material.dart';

import '../pages/settings_page.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'notification_bell_button.dart';

/// The standard SkillMatch top bar: brand mark + title, with settings and notifications.
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
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppColors.borderSoft,
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332563EB),
                  blurRadius: 8,
                  offset: Offset(0, 3),
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
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
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  size: 19,
                  color: AppColors.textSecondary,
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
