import 'dart:async';
import 'dart:convert';

import '../config/api_config.dart';
import '../models/job_match_result.dart';
import 'authed_http.dart';

class JobMatchApiException implements Exception {
  JobMatchApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

Uri _jobMatchUri({
  required String applicantId,
  required String jobId,
}) {
  final safeApplicantId = Uri.encodeComponent(applicantId);
  final safeJobId = Uri.encodeComponent(jobId);
  return Uri.parse(
    '$kApiBaseUrl/api/mobile/match/$safeApplicantId/$safeJobId',
  );
}

String _apiErrorMessage(String fallback, String body) {
  final raw = body.trim();
  if (raw.isEmpty) return fallback;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
  } catch (_) {}
  return fallback;
}

Future<JobMatchResult> fetchJobMatchResult({
  required String applicantId,
  required String jobId,
}) async {
  final uri = _jobMatchUri(applicantId: applicantId, jobId: jobId);

  try {
    final res = await authedGet(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw JobMatchApiException(
        _apiErrorMessage(
          'Could not load job match analytics (${res.statusCode}).',
          res.body,
        ),
        statusCode: res.statusCode,
      );
    }

    final raw = res.body.trim();
    if (raw.isEmpty) {
      throw JobMatchApiException('Empty response from job match analytics API.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw JobMatchApiException(
        'Job match analytics API did not return valid JSON.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw JobMatchApiException('Invalid job match analytics response shape.');
    }

    return JobMatchResult.fromJson(decoded);
  } on TimeoutException {
    throw JobMatchApiException(
      'Job match analytics request timed out. Please try again.',
    );
  } on AuthedException catch (e) {
    throw JobMatchApiException(e.message, statusCode: e.statusCode);
  }
}
