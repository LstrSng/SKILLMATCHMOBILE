import '../models/skill_assessment.dart';
import 'skill_assessment_engine.dart';

Map<String, dynamic>? parseProfileFileItem(
  dynamic raw, {
  required String fallbackName,
}) {
  if (raw is! Map) return null;
  final id = (raw['id'] as Object?)?.toString().trim() ?? '';
  final name = (raw['name'] as Object?)?.toString().trim() ?? '';
  final url = (raw['url'] as Object?)?.toString().trim() ?? '';
  final data = (raw['data'] as Object?)?.toString().trim() ?? '';
  final mimeType = (raw['mimeType'] as Object?)?.toString().trim() ?? '';
  final publicId = (raw['publicId'] as Object?)?.toString().trim() ?? '';
  final sizeRaw = raw['size'];
  final size = sizeRaw is num
      ? sizeRaw.toInt()
      : (int.tryParse(sizeRaw?.toString() ?? '') ?? 0);
  final updatedAt = (raw['updatedAt'] as Object?)?.toString().trim() ?? '';
  if (name.isEmpty && url.isEmpty && data.isEmpty) return null;
  // Extra details of certificates added from an upskilling pathway.
  String? extra(String key) {
    final v = (raw[key] as Object?)?.toString().trim() ?? '';
    return v.isEmpty ? null : v;
  }

  return {
    'id': id.isNotEmpty ? id : (publicId.isNotEmpty ? publicId : name),
    'name': name.isNotEmpty ? name : fallbackName,
    'url': url,
    'data': data,
    'mimeType': mimeType,
    'publicId': publicId,
    'size': size,
    'updatedAt': updatedAt,
    for (final key in const ['title', 'issuer', 'skill', 'source'])
      key: ?extra(key),
  };
}

Map<String, dynamic>? readProfileResume(Map<String, dynamic> profileData) {
  return parseProfileFileItem(profileData['resume'], fallbackName: 'Resume');
}

List<Map<String, dynamic>> readProfileCertifications(
  Map<String, dynamic> profileData,
) {
  final rawList = profileData['certifications'];
  final list = <Map<String, dynamic>>[];
  if (rawList is List) {
    for (final raw in rawList) {
      final item = parseProfileFileItem(raw, fallbackName: 'Certification');
      if (item != null) list.add(item);
    }
  } else {
    final singleRaw = profileData['certification'];
    final item = parseProfileFileItem(singleRaw, fallbackName: 'Certification');
    if (item != null) list.add(item);
  }
  return list;
}

/// Profile completion percentage (0-100). Shared by the Profile tab's
/// Profile Strength meter and the Dashboard's Profile Score so both show
/// the same number.
int profileCompletionPercent(Map<String, dynamic> user) {
  String s(String key) => (user[key] as Object?)?.toString().trim() ?? '';
  bool nonEmptyEntries(String key, List<String> fields) {
    final v = user[key];
    if (v is! List) return false;
    return v.any(
      (it) =>
          it is Map &&
          fields.any(
            (f) => ((it[f] as Object?)?.toString().trim() ?? '').isNotEmpty,
          ),
    );
  }

  final rawProfile = user['profile'];
  final profileData = rawProfile is Map
      ? rawProfile.map((k, v) => MapEntry(k.toString(), v))
      : <String, dynamic>{};
  final skillsRaw = user['skills'];
  final skillCount = skillsRaw is List
      ? skillsRaw.where((e) => e.toString().trim().isNotEmpty).length
      : 0;
  final Map<String, AssessmentResult> assessments = readAssessmentResults(
    profileData,
  );

  var score = 0;
  // 1. Basic Info (25%)
  if (s('firstName').isNotEmpty && s('lastName').isNotEmpty) score += 10;
  if (s('headline').isNotEmpty) score += 5;
  if (s('location').isNotEmpty) score += 5;
  if (s('phone').isNotEmpty || s('email').isNotEmpty) score += 5;

  // 2. Avatar (5%)
  if (s('avatarUrl').isNotEmpty) score += 5;

  // 3. Skills (20%)
  if (skillCount >= 3) {
    score += 20;
  } else if (skillCount > 0) {
    score += 10;
  }

  // 4. Resume (20%)
  if (readProfileResume(profileData) != null) score += 20;

  // 5. Experience (10%)
  if (nonEmptyEntries('experience', const [
    'year',
    'title',
    'company',
    'description',
  ])) {
    score += 10;
  }

  // 6. Education (10%)
  if (nonEmptyEntries('education', const ['degree', 'school', 'years'])) {
    score += 10;
  }

  // 7. Certifications or Assessments (10%)
  if (readProfileCertifications(profileData).isNotEmpty ||
      assessments.isNotEmpty) {
    score += 10;
  }

  return score.clamp(0, 100);
}
