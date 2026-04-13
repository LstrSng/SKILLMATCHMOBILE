import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

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

Future<List<Map<String, dynamic>>> fetchJobsRaw() async {
  final uri = _jobsUri();
  final res = await http.get(
    uri,
    headers: {'Accept': 'application/json'},
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw JobsApiException(
      'Could not load jobs (${res.statusCode}).',
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
