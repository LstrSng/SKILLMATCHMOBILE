import 'dart:convert';
import 'dart:typed_data';

import '../config/cloudinary_config.dart';
import 'cloudinary_service.dart';
import 'profile_api.dart';
import 'session_store.dart';

/// A certificate PDF picked while completing an upskilling step, not yet
/// uploaded.
class CertificationDraft {
  const CertificationDraft({
    required this.fileName,
    required this.bytes,
    required this.title,
    this.issuer,
  });

  final String fileName;
  final Uint8List bytes;

  /// Certificate name shown on the profile, e.g. "JavaScript Algorithms".
  final String title;
  final String? issuer;
}

/// Uploads [draft] and appends it to `profile.certifications`, tagged with
/// the pathway [skill] it was earned for.
Future<Map<String, dynamic>> addPathwayCertification(
  CertificationDraft draft, {
  required String skill,
}) async {
  final now = DateTime.now().toUtc().toIso8601String();
  final item = <String, dynamic>{
    'id': '${DateTime.now().millisecondsSinceEpoch}_pathway',
    'name': draft.fileName,
    'title': draft.title,
    if (draft.issuer != null) 'issuer': draft.issuer,
    'skill': skill,
    'source': 'pathway',
    'mimeType': 'application/pdf',
    'size': draft.bytes.length,
    'updatedAt': now,
  };
  if (CloudinaryConfig.isConfigured) {
    final result = await CloudinaryService.uploadCertification(
      bytes: draft.bytes,
      fileName: draft.fileName,
    );
    item.addAll({
      'url': result.secureUrl,
      'publicId': result.publicId,
      'resourceType': result.resourceType,
      'format': result.format,
    });
  } else {
    // Same base64 fallback as the profile page when Cloudinary isn't set up.
    item['data'] = base64Encode(draft.bytes);
  }

  final raw = SessionStore.user?['profile']?['certifications'];
  final list = [
    if (raw is List)
      for (final e in raw)
        if (e is Map) e.map((k, v) => MapEntry(k.toString(), v)),
    item,
  ];
  return updateMyProfile({
    'profile': {'certifications': list, 'certification': list.first},
  });
}
