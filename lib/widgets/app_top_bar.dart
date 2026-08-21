import 'package:flutter/material.dart';

import '../pages/settings_page.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'notification_bell_button.dart';

/// The standard SkillMatch app bar: brand mark + title, with optional
/// settings and notification actions. Used across the authenticated
/// in-app pages so the header stays visually identical everywhere,
/// instead of every page re-declaring the same Row/Container/IconButton
/// markup inline.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title = 'SkillMatch',
    this.showSettings = true,
    this.showNotifications = true,
  });

  final String title;
  final bool showSettings;
  final bool showNotifications;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bolt, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        if (showSettings)
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        if (showNotifications) const NotificationBellButton(),
        const SizedBox(width: 8),
      ],
    );
  }
}
