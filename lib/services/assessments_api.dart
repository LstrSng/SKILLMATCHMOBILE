import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/skill_assessment.dart';
import 'authed_http.dart';

Uri _assessmentsUri({String? track, String? search, String? roleId}) {
  final params = <String, String>{};
  if (track != null && track.trim().isNotEmpty && track.trim().toLowerCase() != 'all') {
    params['track'] = track.trim();
  }
  if (search != null && search.trim().isNotEmpty) {
    params['search'] = search.trim();
  }
  if (roleId != null && roleId.trim().isNotEmpty) {
    params['roleId'] = roleId.trim();
  }
  final query = params.isNotEmpty ? '?${Uri(queryParameters: params).query}' : '';
  return Uri.parse('$kApiBaseUrl/api/assessments$query');
}

Uri _assessmentByIdUri(String id) => Uri.parse('$kApiBaseUrl/api/assessments/$id');
Uri _submitAssessmentUri(String id) => Uri.parse('$kApiBaseUrl/api/assessments/$id/submit');

const _kTimeout = Duration(seconds: 20);

Future<T> _withNetworkErrors<T>(Future<T> Function() run) async {
  try {
    return await run().timeout(_kTimeout);
  } on TimeoutException {
    throw AuthedException('Request timed out while loading assessments. Please check your connection.');
  } on http.ClientException {
    throw AuthedException('Could not reach the backend API. Please make sure the server is running.');
  }
}

/// Fetches all role assessments from MongoDB.
Future<List<AssessmentCategory>> fetchAssessments({
  String? track,
  String? search,
  String? roleId,
}) async {
  return _withNetworkErrors(() async {
    final uri = _assessmentsUri(track: track, search: search, roleId: roleId);
    final res = await authedGet(uri);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthedException(
        'Could not load assessments (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw AuthedException('Invalid assessments response.');
    final list = decoded['assessments'];
    if (list is! List) throw AuthedException('Invalid assessments list.');

    return list
        .whereType<Map>()
        .map((e) => AssessmentCategory.fromJson(e))
        .toList();
  });
}

/// Fetches a single assessment with all questions from MongoDB.
Future<AssessmentCategory> fetchAssessmentById(String id) async {
  return _withNetworkErrors(() async {
    final res = await authedGet(_assessmentByIdUri(id));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthedException(
        'Could not load assessment details (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw AuthedException('Invalid assessment response.');
    final doc = decoded['assessment'];
    if (doc is! Map) throw AuthedException('Assessment details missing in response.');

    return AssessmentCategory.fromJson(doc);
  });
}

/// Submits an assessment result to MongoDB and updates the user profile so employers can view it.
Future<Map<String, dynamic>> submitAssessment({
  required String assessmentId,
  required int correctCount,
  required int totalCount,
  List<Map<String, dynamic>>? answers,
}) async {
  return _withNetworkErrors(() async {
    final res = await authedPost(
      _submitAssessmentUri(assessmentId),
      body: jsonEncode({
        'correctCount': correctCount,
        'totalCount': totalCount,
        'answers': answers ?? [],
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthedException(
        'Could not submit assessment (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw AuthedException('Invalid submit response.');
    return decoded.map((k, v) => MapEntry(k.toString(), v));
  });
}
