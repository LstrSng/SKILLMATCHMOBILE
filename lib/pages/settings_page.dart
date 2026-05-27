import 'package:flutter/material.dart';

import '../services/session_store.dart';
import 'sign_in_page.dart';
import '../widgets/notification_bell_button.dart';

class SettingsPage extends StatefulWidget {
  final int initialTab;
  const SettingsPage({super.key, this.initialTab = 0});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _jobMatches = true;
  bool _applicationUpdates = true;
  bool _weeklyDigest = false;

  Future<void> _logOut() async {
    await SessionStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SignInPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
            const Text(
              'SkillMatch',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
          const NotificationBellButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage your notification preferences',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Preferences',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage alerts for jobs and application activity',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 20),
                  _NotificationToggle(
                    title: 'Job Matches',
                    subtitle: 'New jobs matching your profile',
                    value: _jobMatches,
                    onChanged: (value) {
                      setState(() {
                        _jobMatches = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 20),
                  _NotificationToggle(
                    title: 'Application Updates',
                    subtitle: 'Status changes on applications',
                    value: _applicationUpdates,
                    onChanged: (value) {
                      setState(() {
                        _applicationUpdates = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 20),
                  _NotificationToggle(
                    title: 'Weekly Digest',
                    subtitle: 'Weekly summary of activity',
                    value: _weeklyDigest,
                    onChanged: (value) {
                      setState(() {
                        _weeklyDigest = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logOut,
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF2563EB),
        ),
      ],
    );
  }
}
