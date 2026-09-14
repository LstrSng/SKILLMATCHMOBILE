import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'authed_http.dart';

class JobsApiException implements Exception {
  JobsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

const String _kJobsCacheKey = 'cache.jobs.raw';
const Duration _kJobsNetworkTimeout = Duration(seconds: 20);

List<Map<String, dynamic>>? _memoryCachedJobs;
Future<List<Map<String, dynamic>>>? _inFlightFetchJobs;

/// Synchronously returns any in-memory cached jobs if available.
List<Map<String, dynamic>>? get memoryCachedJobs => _memoryCachedJobs;

/// Clears in-memory cached jobs.
void clearJobsCache() {
  _memoryCachedJobs = null;
}

/// Returns cached jobs from memory or disk (SharedPreferences) for instant display.
Future<List<Map<String, dynamic>>> getCachedJobsRaw() async {
  if (_memoryCachedJobs != null && _memoryCachedJobs!.isNotEmpty) {
    return _memoryCachedJobs!;
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kJobsCacheKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .map((e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map))
            .toList();
        if (list.isNotEmpty) {
          _memoryCachedJobs = list;
          return list;
        }
      }
    }
  } catch (_) {}
  return [];
}

Future<void> _saveJobsToCache(List<Map<String, dynamic>> jobs) async {
  _memoryCachedJobs = jobs;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kJobsCacheKey, jsonEncode(jobs));
  } catch (_) {}
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
  final inFlight = _inFlightFetchJobs;
  if (inFlight != null) return inFlight;

  final future = () async {
    final uri = _jobsUri();
    http.Response res;
    try {
      res = await authedGet(uri).timeout(_kJobsNetworkTimeout);
    } on TimeoutException {
      throw JobsApiException(
        'Request timed out while loading jobs. Please check your internet connection.',
      );
    } on http.ClientException {
      throw JobsApiException(
        'Unable to connect to server. Please check your internet connection.',
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
    final parsed = list
        .map((e) => e is Map<String, dynamic>
            ? e
            : Map<String, dynamic>.from(e as Map))
        .toList();
    unawaited(_saveJobsToCache(parsed));
    return parsed;
  }();

  _inFlightFetchJobs = future;
  try {
    return await future;
  } finally {
    _inFlightFetchJobs = null;
  }
}

