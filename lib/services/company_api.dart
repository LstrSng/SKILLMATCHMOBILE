import 'dart:convert';

import '../config/api_config.dart';
import 'authed_http.dart';

Uri _companyUri(String jobId) =>
    Uri.parse('$kApiBaseUrl/api/jobs/$jobId/company');

Future<Map<String, dynamic>> fetchCompanyDetails(String jobId) {
  return withNetworkErrors(() async {
    final res = await authedGet(_companyUri(jobId));
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
  });
}
