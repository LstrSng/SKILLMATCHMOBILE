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

Future<http.Response> authedGet(Uri uri) async {
  final res = await http.get(uri, headers: jsonHeaders());
  return res;
}

Future<http.Response> authedPut(Uri uri, {required String body}) async {
  final res = await http.put(uri, headers: jsonHeaders(), body: body);
  return res;
}

Future<http.Response> authedPost(Uri uri, {required String body}) async {
  final res = await http.post(uri, headers: jsonHeaders(), body: body);
  return res;
}

Future<http.Response> authedPatch(Uri uri, {required String body}) async {
  final res = await http.patch(uri, headers: jsonHeaders(), body: body);
  return res;
}

