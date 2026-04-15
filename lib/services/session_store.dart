import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _kTokenKey = 'auth.token';
  static const _kUserKey = 'auth.user';

  static String? _token;
  static Map<String, dynamic>? _user;

  static String? get token => _token;
  static Map<String, dynamic>? get user => _user;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
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

  static Future<void> save({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    _token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
    await prefs.setString(_kUserKey, jsonEncode(user));
  }

  static Future<void> updateUser(Map<String, dynamic> user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(user));
  }

  static Future<void> clear() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserKey);
  }
}

