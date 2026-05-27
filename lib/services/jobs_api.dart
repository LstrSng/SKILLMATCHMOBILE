import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'authed_http.dart';

class JobsApiException implements Exception {
  JobsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

Uri _jobsUri() {
  const p = String.fromEnvironment(
    'JOBS_LIST_PATH',
    defaultValue: '/api/jobs',
  );
  final path = p.startsWith('/') ? p : '/$p';
  return Uri.parse('$kApiBaseUrl$path');
}

String _readErrorMessage(String body) {
  final raw = body.trim();
  if (raw.isEmpty) return '';
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
  } catch (_) {
    // Fall back to a generic status error if the body is not JSON.
  }
  return '';
}

Future<List<Map<String, dynamic>>> fetchJobsRaw() async {
  final uri = _jobsUri();
  http.Response res;
  try {
    res = await authedGet(uri).timeout(const Duration(seconds: 10));
  } on TimeoutException {
    throw JobsApiException(
      'Request timed out while loading jobs. Make sure the API is running and reachable at $uri.',
    );
  } on http.ClientException {
    throw JobsApiException(
      'Could not reach the API at $uri. Start the backend and confirm the emulator can access your PC on that port.',
    );
  }
  if (res.statusCode < 200 || res.statusCode >= 300) {
    final message = _readErrorMessage(res.body);
    throw JobsApiException(
      message.isNotEmpty
          ? '$message (${res.statusCode}).'
          : 'Could not load jobs (${res.statusCode}).',
      statusCode: res.statusCode,
    );
  }
  final raw = res.body.trim();
  if (raw.isEmpty) {
    throw JobsApiException('Empty response from server.');
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    throw JobsApiException('Server did not return JSON for jobs.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw JobsApiException('Invalid jobs response shape.');
  }
  final list = decoded['jobs'];
  if (list is! List) {
    throw JobsApiException('Invalid jobs response (missing jobs array).');
  }
  return list
      .map((e) => e is Map<String, dynamic>
          ? e
          : Map<String, dynamic>.from(e as Map))
      .toList();
}
