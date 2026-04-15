import 'dart:convert';

import '../config/api_config.dart';
import 'authed_http.dart';

Uri _appsUri() => Uri.parse('$kApiBaseUrl/api/applications');
Uri _appUri(String id) => Uri.parse('$kApiBaseUrl/api/applications/$id');

Future<List<Map<String, dynamic>>> fetchMyApplications() async {
  final res = await authedGet(_appsUri());
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw AuthedException(
      'Could not load applications (${res.statusCode}).',
      statusCode: res.statusCode,
    );
  }
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) throw AuthedException('Invalid applications response.');
  final list = decoded['applications'];
  if (list is! List) throw AuthedException('Invalid applications response.');
  return list
      .map((e) => e is Map<String, dynamic>
          ? e
          : Map<String, dynamic>.from(e as Map))
      .toList();
}

Future<Map<String, dynamic>> applyToJob({
  required String jobId,
  required Map<String, dynamic> jobSnapshot,
}) async {
  final res = await authedPost(
    _appsUri(),
    body: jsonEncode({'jobId': jobId, 'jobSnapshot': jobSnapshot}),
  );
  if (res.statusCode == 409) {
    throw AuthedException('You already applied to this job.', statusCode: 409);
  }
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw AuthedException(
      'Could not apply (${res.statusCode}).',
      statusCode: res.statusCode,
    );
  }
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) throw AuthedException('Invalid apply response.');
  final app = decoded['application'];
  if (app is! Map) throw AuthedException('Invalid apply response (application).');
  return app.map((k, v) => MapEntry(k.toString(), v));
}

Future<Map<String, dynamic>> updateApplicationStatus({
  required String applicationId,
  required String status,
}) async {
  final res =
      await authedPatch(_appUri(applicationId), body: jsonEncode({'status': status}));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw AuthedException(
      'Could not update status (${res.statusCode}).',
      statusCode: res.statusCode,
    );
  }
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) throw AuthedException('Invalid update response.');
  final app = decoded['application'];
  if (app is! Map) throw AuthedException('Invalid update response (application).');
  return app.map((k, v) => MapEntry(k.toString(), v));
}

