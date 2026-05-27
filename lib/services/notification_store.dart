import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'applications_api.dart';
import 'session_store.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] as Object?)?.toString() ?? '',
      title: (json['title'] as Object?)?.toString() ?? 'Notification',
      message: (json['message'] as Object?)?.toString() ?? '',
      createdAt:
          DateTime.tryParse((json['createdAt'] as Object?)?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class NotificationStore {
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  static String _storageKey() {
    final userId =
        (SessionStore.user?['_id'] ?? SessionStore.user?['id'])?.toString() ??
        'guest';
    return 'notifications.$userId';
  }

  static String _statusSnapshotKey() {
    final userId =
        (SessionStore.user?['_id'] ?? SessionStore.user?['id'])?.toString() ??
        'guest';
    return 'application-statuses.$userId';
  }

  static String _lastReadKey() {
    final userId =
        (SessionStore.user?['_id'] ?? SessionStore.user?['id'])?.toString() ??
        'guest';
    return 'notifications-last-read.$userId';
  }

  static Future<List<AppNotification>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey());
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final list = decoded
          .map(
            (item) => AppNotification.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<AppNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(),
      jsonEncode(notifications.map((item) => item.toJson()).toList()),
    );
  }

  static Future<void> add(AppNotification notification) async {
    final current = await load();
    if (current.any((item) => item.id == notification.id)) return;
    current.insert(0, notification);
    await saveAll(current);
    await refreshUnreadCount();
  }

  static Future<DateTime?> loadLastReadAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastReadKey());
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<int> getUnreadCount() async {
    final notifications = await load();
    final lastReadAt = await loadLastReadAt();
    if (lastReadAt == null) return notifications.length;
    return notifications
        .where((item) => item.createdAt.isAfter(lastReadAt))
        .length;
  }

  static Future<void> refreshUnreadCount() async {
    unreadCountNotifier.value = await getUnreadCount();
  }

  static Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastReadKey(), DateTime.now().toIso8601String());
    unreadCountNotifier.value = 0;
  }

  static Future<void> syncApplicationUpdatesFromList(
    List<Map<String, dynamic>> rawApplications,
  ) async {
    final previousStatuses = await loadApplicationStatuses();
    final nextStatuses = <String, String>{};

    for (final raw in rawApplications) {
      final id = (raw['_id'] as Object?)?.toString().trim() ?? '';
      if (id.isEmpty) continue;

      final status = (raw['status'] as Object?)?.toString().trim() ?? 'Applied';
      nextStatuses[id] = status;

      final oldStatus = previousStatuses[id];
      if (status == 'Withdrawn') continue;

      final snapshot = raw['jobSnapshot'];
      final title =
          snapshot is Map
              ? (snapshot['title'] as Object?)?.toString().trim() ?? ''
              : '';
      final notificationTitle = title.isEmpty ? 'Application Update' : title;

      if (oldStatus != null && oldStatus != status) {
        await add(
          AppNotification(
            id: '$id:$status',
            title: notificationTitle,
            message: 'Your application status changed from $oldStatus to $status.',
            createdAt: DateTime.now(),
          ),
        );
        continue;
      }

      if (oldStatus == null && status != 'Applied') {
        String message = 'Your application status is now $status.';
        final history = raw['statusHistory'];
        if (history is List && history.length >= 2) {
          final previousEntry = history[history.length - 2];
          if (previousEntry is Map) {
            final previousStatus =
                (previousEntry['status'] as Object?)?.toString().trim() ?? '';
            if (previousStatus.isNotEmpty && previousStatus != status) {
              message =
                  'Your application status changed from $previousStatus to $status.';
            }
          }
        }

        await add(
          AppNotification(
            id: '$id:$status',
            title: notificationTitle,
            message: message,
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    await saveApplicationStatuses(nextStatuses);
  }

  static Future<void> syncApplicationUpdates() async {
    final rawApplications = await fetchMyApplications();
    await syncApplicationUpdatesFromList(rawApplications);
  }

  static Future<Map<String, String>> loadApplicationStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statusSnapshotKey());
    if (raw == null || raw.trim().isEmpty) return const {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return const {};
    }
  }

  static Future<void> saveApplicationStatuses(
    Map<String, String> statuses,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statusSnapshotKey(), jsonEncode(statuses));
  }
}
