import 'dart:convert';

import '../config/api_config.dart';
import 'authed_http.dart';
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

Future<Map<String, dynamic>> fetchMyProfile() async {
  final res = await authedGet(_meUri());
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
}

Future<Map<String, dynamic>> updateMyProfile(Map<String, dynamic> patch) async {
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
}
