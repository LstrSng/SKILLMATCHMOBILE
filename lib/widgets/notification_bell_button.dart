import 'package:flutter/material.dart';

import '../pages/notifications_page.dart';
import '../services/notification_store.dart';

class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key, this.iconColor});

  final Color? iconColor;

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  @override
  void initState() {
    super.initState();
    _primeNotifications();
  }

  Future<void> _primeNotifications() async {
    try {
      await NotificationStore.syncApplicationUpdates();
    } catch (_) {
      // Fall back to the locally cached unread count if sync fails.
    }
    await NotificationStore.refreshUnreadCount();
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsPage()),
    );
    await _primeNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationStore.unreadCountNotifier,
      builder: (context, unreadCount, _) {
        return IconButton(
          onPressed: _openNotifications,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications,
                color: widget.iconColor,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
