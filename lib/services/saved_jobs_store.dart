import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'session_store.dart';

/// Persists which job IDs the current user has bookmarked, so the bookmark
/// icon on a job's details survives navigating away and reopening the app.
class SavedJobsStore {
  static String _storageKey() {
    final userId =
        (SessionStore.user?['_id'] ?? SessionStore.user?['id'])?.toString() ??
        'guest';
    return 'saved-jobs.$userId';
  }

  static Future<Set<String>> loadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey());
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<bool> isSaved(String jobId) async {
    if (jobId.trim().isEmpty) return false;
    final ids = await loadIds();
    return ids.contains(jobId);
  }

  static Future<Set<String>> toggle(String jobId) async {
    final ids = await loadIds();
    if (ids.contains(jobId)) {
      ids.remove(jobId);
    } else {
      ids.add(jobId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(), jsonEncode(ids.toList()));
    return ids;
  }
}
