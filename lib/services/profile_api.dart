import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'authed_http.dart';
import 'session_store.dart';

Uri _meUri() => Uri.parse('$kApiBaseUrl/api/me');

const _kTimeout = Duration(seconds: 20);

Future<T> _withNetworkErrors<T>(Future<T> Function() run) async {
  try {
    return await run().timeout(_kTimeout);
  } on TimeoutException {
    throw AuthedException('Request timed out. Please check your connection and try again.');
  } on http.ClientException {
    throw AuthedException('Unable to connect to server. Please check your internet connection.');
  }
}

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

  final future = _withNetworkErrors(() async {
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
  return _withNetworkErrors(() async {
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
