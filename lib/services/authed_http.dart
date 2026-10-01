import 'dart:async';
import 'package:http/http.dart' as http;

import 'session_store.dart';

Map<String, String> jsonHeaders({bool authed = true}) {
  final h = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  if (authed) {
    final t = SessionStore.token;
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
  }
  return h;
}

class AuthedException implements Exception {
  AuthedException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

const Duration _kHttpTimeout = Duration(seconds: 45);

/// Runs [run] with a [timeout], turning timeouts and connection failures
/// into an [AuthedException] with a user-facing message.
Future<T> withNetworkErrors<T>(
  Future<T> Function() run, {
  Duration timeout = const Duration(seconds: 20),
  String timeoutMessage =
      'Request timed out. Please check your connection and try again.',
  String offlineMessage =
      'Unable to connect to server. Please check your internet connection.',
}) async {
  try {
    return await run().timeout(timeout);
  } on TimeoutException {
    throw AuthedException(timeoutMessage);
  } on http.ClientException {
    throw AuthedException(offlineMessage);
  }
}

Future<http.Response> authedGet(Uri uri) async {
  try {
    final res = await http
        .get(uri, headers: jsonHeaders())
        .timeout(_kHttpTimeout);
    return res;
  } on TimeoutException {
    throw AuthedException(
      'Connection timed out. The server may be waking up, please try again.',
    );
  }
}

Future<http.Response> authedPut(Uri uri, {required String body}) async {
  try {
    final res = await http
        .put(uri, headers: jsonHeaders(), body: body)
        .timeout(_kHttpTimeout);
    return res;
  } on TimeoutException {
    throw AuthedException(
      'Connection timed out. The server may be waking up, please try again.',
    );
  }
}

Future<http.Response> authedPost(Uri uri, {required String body}) async {
  try {
    final res = await http
        .post(uri, headers: jsonHeaders(), body: body)
        .timeout(_kHttpTimeout);
    return res;
  } on TimeoutException {
    throw AuthedException(
      'Connection timed out. The server may be waking up, please try again.',
    );
  }
}

Future<http.Response> authedPatch(Uri uri, {required String body}) async {
  try {
    final res = await http
        .patch(uri, headers: jsonHeaders(), body: body)
        .timeout(_kHttpTimeout);
    return res;
  } on TimeoutException {
    throw AuthedException(
      'Connection timed out. The server may be waking up, please try again.',
    );
  }
}
