import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'authed_http.dart';
import 'session_store.dart';

Uri _appsUri() => Uri.parse('$kApiBaseUrl/api/applications');
Uri _appUri(String id) => Uri.parse('$kApiBaseUrl/api/applications/$id');

const _kTimeout = Duration(seconds: 20);

String _appsCacheKey() {
  final userId =
      (SessionStore.user?['_id'] ?? SessionStore.user?['id'])?.toString() ??
      'guest';
  return 'cache.applications.$userId';
}

List<Map<String, dynamic>>? _memoryCachedApplications;
Future<List<Map<String, dynamic>>>? _inFlightFetchMyApplications;

/// Synchronously returns in-memory cached applications if available.
List<Map<String, dynamic>>? get memoryCachedApplications =>
    _memoryCachedApplications;

/// Clears in-memory cached applications (e.g. on user sign-out).
void clearApplicationsCache() {
  _memoryCachedApplications = null;
}

/// Returns cached applications from memory or disk (SharedPreferences) for instant display.
Future<List<Map<String, dynamic>>> getCachedMyApplications() async {
  if (_memoryCachedApplications != null &&
      _memoryCachedApplications!.isNotEmpty) {
    return _memoryCachedApplications!;
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appsCacheKey());
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .map((e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map))
            .toList();
        if (list.isNotEmpty) {
          _memoryCachedApplications = list;
          return list;
        }
      }
    }
  } catch (_) {}
  return [];
}

Future<void> _saveApplicationsToCache(List<Map<String, dynamic>> apps) async {
  _memoryCachedApplications = apps;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appsCacheKey(), jsonEncode(apps));
  } catch (_) {}
}

Future<T> _withNetworkErrors<T>(Future<T> Function() run) async {
  try {
    return await run().timeout(_kTimeout);
  } on TimeoutException {
    throw AuthedException('Request timed out. Please check your connection and try again.');
  } on http.ClientException {
    throw AuthedException('Unable to connect to server. Please check your internet connection.');
  }
}

Future<List<Map<String, dynamic>>> fetchMyApplications() async {
  final inFlight = _inFlightFetchMyApplications;
  if (inFlight != null) return inFlight;

  final future = _withNetworkErrors(() async {
    final res = await authedGet(_appsUri());
    if (res.statusCode == 401) {
      await SessionStore.clear();
      throw AuthedException('Invalid auth token.', statusCode: 401);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthedException(
        'Could not load applications (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw AuthedException('Invalid applications response.');
    final list = decoded['applications'];
    if (list is! List) throw AuthedException('Invalid applications response.');
    final parsed = list
        .map((e) => e is Map<String, dynamic>
            ? e
            : Map<String, dynamic>.from(e as Map))
        .toList();
    unawaited(_saveApplicationsToCache(parsed));
    return parsed;
  });

  _inFlightFetchMyApplications = future;
  try {
    return await future;
  } finally {
    _inFlightFetchMyApplications = null;
  }
}

Future<Map<String, dynamic>> applyToJob({
  required String jobId,
  required Map<String, dynamic> jobSnapshot,
}) async {
  return _withNetworkErrors(() async {
    final res = await authedPost(
      _appsUri(),
      body: jsonEncode({'jobId': jobId, 'jobSnapshot': jobSnapshot}),
    );
    if (res.statusCode == 409) {
      throw AuthedException('You already applied to this job.', statusCode: 409);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthedException(
        'Could not apply (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw AuthedException('Invalid apply response.');
    final app = decoded['application'];
    if (app is! Map) throw AuthedException('Invalid apply response (application).');
    return app.map((k, v) => MapEntry(k.toString(), v));
  });
}

Future<Map<String, dynamic>> updateApplicationStatus({
  required String applicationId,
  required String status,
}) async {
  return _withNetworkErrors(() async {
    final res = await authedPatch(
      _appUri(applicationId),
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Could not update status (${res.statusCode}).';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson is Map && errJson['message'] != null) {
          msg = errJson['message'].toString();
        }
      } catch (_) {}
      throw AuthedException(
        msg,
        statusCode: res.statusCode,
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw AuthedException('Invalid update response.');
    final app = decoded['application'];
    if (app is! Map) throw AuthedException('Invalid update response (application).');
    return app.map((k, v) => MapEntry(k.toString(), v));
  });
}

