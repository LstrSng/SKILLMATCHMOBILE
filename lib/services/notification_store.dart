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

  static String _seenJobIdsKey() {
    final userId =
        (SessionStore.user?['_id'] ?? SessionStore.user?['id'])?.toString() ??
        'guest';
    return 'notifications-seen-jobs.$userId';
  }

  static String _lastDigestAtKey() {
    final userId =
        (SessionStore.user?['_id'] ?? SessionStore.user?['id'])?.toString() ??
        'guest';
    return 'notifications-last-digest.$userId';
  }

  static String _preferenceKey(String name) {
    final userId =
        (SessionStore.user?['_id'] ?? SessionStore.user?['id'])?.toString() ??
        'guest';
    return 'notification-pref.$name.$userId';
  }

  /// Preference keys used by the Settings page toggles.
  static const kPrefJobMatches = 'jobMatches';
  static const kPrefApplicationUpdates = 'applicationUpdates';
  static const kPrefWeeklyDigest = 'weeklyDigest';

  static Future<bool> getPreference(String name, {required bool defaultValue}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_preferenceKey(name)) ?? defaultValue;
  }

  static Future<void> setPreference(String name, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferenceKey(name), value);
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
    final notifyEnabled = await getPreference(
      kPrefApplicationUpdates,
      defaultValue: true,
    );

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
        if (notifyEnabled) {
          await add(
            AppNotification(
              id: '$id:$status',
              title: notificationTitle,
              message: 'Your application status changed from $oldStatus to $status.',
              createdAt: DateTime.now(),
            ),
          );
        }
        continue;
      }

      if (oldStatus == null && status != 'Applied') {
        if (notifyEnabled) {
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
    }

    await saveApplicationStatuses(nextStatuses);
  }

  static Future<void> syncApplicationUpdates() async {
    final rawApplications = await fetchMyApplications();
    await syncApplicationUpdatesFromList(rawApplications);
  }

  /// Compares freshly fetched job IDs against the set already seen on this
  /// device and, when the "Job Matches" preference is on, raises a
  /// notification for genuinely new postings. Call this after loading the
  /// jobs list (e.g. from the Jobs page).
  static Future<void> syncNewJobMatches(
    List<MapEntry<String, String>> jobs, // (id, title)
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final seenRaw = prefs.getString(_seenJobIdsKey());
    Set<String> seen;
    if (seenRaw == null) {
      // First run on this device: seed with the current jobs instead of
      // notifying about every existing posting at once.
      seen = jobs.map((j) => j.key).where((id) => id.isNotEmpty).toSet();
      await prefs.setString(_seenJobIdsKey(), jsonEncode(seen.toList()));
      return;
    }
    try {
      final decoded = jsonDecode(seenRaw);
      seen = decoded is List ? decoded.map((e) => e.toString()).toSet() : {};
    } catch (_) {
      seen = {};
    }

    final newJobs = jobs
        .where((j) => j.key.isNotEmpty && !seen.contains(j.key))
        .toList();

    final nextSeen = {...seen, ...jobs.map((j) => j.key)};
    await prefs.setString(_seenJobIdsKey(), jsonEncode(nextSeen.toList()));

    if (newJobs.isEmpty) return;
    final enabled = await getPreference(kPrefJobMatches, defaultValue: true);
    if (!enabled) return;

    final message = newJobs.length == 1
        ? '${newJobs.first.value} was just posted.'
        : '${newJobs.length} new jobs match your profile.';
    await add(
      AppNotification(
        id: 'job-matches:${DateTime.now().millisecondsSinceEpoch}',
        title: 'New Job Matches',
        message: message,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Adds a weekly summary notification at most once every 7 days, when the
  /// "Weekly Digest" preference is on. Call this after loading applications
  /// (e.g. from the Applications page), passing the current active count.
  static Future<void> maybeAddWeeklyDigest({
    required int activeApplicationCount,
  }) async {
    final enabled = await getPreference(kPrefWeeklyDigest, defaultValue: false);
    if (!enabled) return;

    final prefs = await SharedPreferences.getInstance();
    final lastRaw = prefs.getString(_lastDigestAtKey());
    final last = lastRaw != null ? DateTime.tryParse(lastRaw) : null;
    final now = DateTime.now();
    if (last != null && now.difference(last) < const Duration(days: 7)) {
      return;
    }

    await prefs.setString(_lastDigestAtKey(), now.toIso8601String());
    await add(
      AppNotification(
        id: 'weekly-digest:${now.millisecondsSinceEpoch}',
        title: 'Weekly Digest',
        message: activeApplicationCount > 0
            ? 'You have $activeApplicationCount active application${activeApplicationCount == 1 ? '' : 's'} this week. Keep it up!'
            : 'No active applications this week — check Jobs for new matches.',
        createdAt: now,
      ),
    );
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
