import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _kTokenKey = 'auth.token';
  static const _kUserKey = 'auth.user';
  static const _kExpiresAtKey = 'auth.expiresAt';
  static const _kDeviceTokenKey = 'auth.deviceToken';
  static const Duration _kRememberDuration = Duration(days: 30);

  static String? _token;
  static Map<String, dynamic>? _user;
  static String? _deviceToken;

  static String? get token => _token;
  static Map<String, dynamic>? get user => _user;

  static String? get deviceToken => _deviceToken;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _deviceToken = prefs.getString(_kDeviceTokenKey);

    final expiresAtRaw = prefs.getString(_kExpiresAtKey);
    if (expiresAtRaw != null) {
      final expiresAt = DateTime.tryParse(expiresAtRaw);
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        // Remembered session expired; sign the user out.
        await prefs.remove(_kTokenKey);
        await prefs.remove(_kUserKey);
        await prefs.remove(_kExpiresAtKey);
        return;
      }
    }

    _token = prefs.getString(_kTokenKey);
    final rawUser = prefs.getString(_kUserKey);
    if (rawUser != null && rawUser.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUser);
        if (decoded is Map) {
          _user = decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {
        _user = null;
      }
    }
  }

  static Future<void> saveDeviceToken(String deviceToken) async {
    _deviceToken = deviceToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceTokenKey, deviceToken);
  }

  static Future<void> save({
    required String token,
    required Map<String, dynamic> user,
    bool remember = true,
  }) async {
    _token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    if (!remember) {
      await prefs.remove(_kTokenKey);
      await prefs.remove(_kUserKey);
      await prefs.remove(_kExpiresAtKey);
      return;
    }
    await prefs.setString(_kTokenKey, token);
    await prefs.setString(_kUserKey, jsonEncode(user));
    await prefs.setString(
      _kExpiresAtKey,
      DateTime.now().add(_kRememberDuration).toIso8601String(),
    );
  }

  static Future<void> updateUser(Map<String, dynamic> user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    // Only touch disk if this session was persisted in the first place —
    // otherwise a "don't remember me" session would get silently persisted.
    if (prefs.containsKey(_kTokenKey)) {
      await prefs.setString(_kUserKey, jsonEncode(user));
    }
  }

  static Future<void> clear() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserKey);
    await prefs.remove(_kExpiresAtKey);
  }
}
