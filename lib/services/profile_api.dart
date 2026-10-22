import 'dart:async';
import 'dart:convert';

import '../config/api_config.dart';
import 'authed_http.dart';
import 'job_roles_data.dart' show plainSkillName;
import 'session_store.dart';

Uri _meUri() => Uri.parse('$kApiBaseUrl/api/me');

String _apiErrorMessage(String fallback, String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['message'] != null) {
      final msg = decoded['message'].toString().trim();
      if (msg.isNotEmpty) return msg;
    }
  } catch (_) {}
  return fallback;
}

Future<Map<String, dynamic>>? _inFlightFetchProfile;

/// Clears in-flight profile fetch future.
void clearProfileCache() {
  _inFlightFetchProfile = null;
}

Future<Map<String, dynamic>> fetchMyProfile() async {
  final inFlight = _inFlightFetchProfile;
  if (inFlight != null) return inFlight;

  final future = withNetworkErrors(() async {
    final res = await authedGet(_meUri());
    if (res.statusCode == 401) {
      await SessionStore.clear();
      throw AuthedException('Invalid auth token.', statusCode: 401);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = _apiErrorMessage(
        'Could not load profile (${res.statusCode}).',
        res.body,
      );
      throw AuthedException(message, statusCode: res.statusCode);
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw AuthedException('Invalid profile response.');
    final user = decoded['user'];
    if (user is! Map) throw AuthedException('Invalid profile response (user).');
    final map = user.map((k, v) => MapEntry(k.toString(), v));
    await SessionStore.updateUser(map);
    return map;
  });

  _inFlightFetchProfile = future;
  try {
    return await future;
  } finally {
    _inFlightFetchProfile = null;
  }
}

Future<Map<String, dynamic>> updateMyProfile(Map<String, dynamic> patch) async {
  return withNetworkErrors(() async {
    final res = await authedPut(_meUri(), body: jsonEncode(patch));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = _apiErrorMessage(
        'Could not save profile (${res.statusCode}).',
        res.body,
      );
      throw AuthedException(message, statusCode: res.statusCode);
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw AuthedException('Invalid profile response.');
    final user = decoded['user'];
    if (user is! Map) throw AuthedException('Invalid profile response (user).');
    final map = user.map((k, v) => MapEntry(k.toString(), v));
    await SessionStore.updateUser(map);
    return map;
  });
}

/// Adds [skill] to the user's skills at a 1–10 [level], or updates its
/// level if the user already has it (matched by plain name, ignoring case).
Future<Map<String, dynamic>> setMySkillLevel(String skill, int level) {
  final name = skill.trim();
  final key = plainSkillName(name).toLowerCase();
  final user = SessionStore.user;
  final rawSkills = user?['skills'];
  final skills = [
    if (rawSkills is List)
      for (final s in rawSkills)
        if (s.toString().trim().isNotEmpty) s.toString().trim(),
  ];
  final levels = <String, dynamic>{
    if (user?['skillLevels'] case final Map raw)
      for (final e in raw.entries) e.key.toString(): e.value,
  };
  final existing = skills.firstWhere(
    (s) => plainSkillName(s).toLowerCase() == key,
    orElse: () => '',
  );
  if (existing.isEmpty) skills.add(name);
  final key2 = existing.isEmpty ? name : existing;
  levels[key2] = level.clamp(1, 10);
  // A manual rating replaces any years entered earlier for this skill.
  final years = <String, dynamic>{
    if (user?['skillYears'] case final Map raw)
      for (final e in raw.entries)
        if (e.key.toString() != key2) e.key.toString(): e.value,
  };
  return updateMyProfile({
    'skills': skills,
    'skillLevels': levels,
    'skillYears': years,
  });
}
