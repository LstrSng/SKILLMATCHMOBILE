import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'authed_http.dart';

Uri _companyUri(String jobId) =>
    Uri.parse('$kApiBaseUrl/api/jobs/$jobId/company');

const _kTimeout = Duration(seconds: 20);

Future<Map<String, dynamic>> fetchCompanyDetails(String jobId) async {
  try {
    final res = await authedGet(_companyUri(jobId)).timeout(_kTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthedException(
        'Could not load company details (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw AuthedException('Invalid company response.');
    final company = decoded['company'];
    if (company is! Map) {
      throw AuthedException('Invalid company response (company).');
    }
    return company.map((k, v) => MapEntry(k.toString(), v));
  } on TimeoutException {
    throw AuthedException(
      'Request timed out. Please check your connection and try again.',
    );
  } on http.ClientException {
    throw AuthedException(
      'Unable to connect to server. Please check your internet connection.',
    );
  }
}
