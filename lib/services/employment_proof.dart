import 'dart:convert';
import 'dart:typed_data';

import '../config/cloudinary_config.dart';
import 'cloudinary_service.dart';

/// Max size of a Certificate of Employment PDF.
const int kMaxEmploymentProofBytes = 10 * 1024 * 1024;

/// The user's stored experience items, keeping every field (including the
/// `proof` file), minus blank rows — same order the profile shows them.
List<Map<String, dynamic>> storedExperienceItems(Map<String, dynamic> user) {
  final v = user['experience'];
  if (v is! List) return [];
  String f(Map it, String k) => (it[k] as Object?)?.toString().trim() ?? '';
  return [
    for (final it in v)
      if (it is Map &&
          [
            'year',
            'title',
            'company',
            'description',
          ].any((k) => f(it, k).isNotEmpty))
        Map<String, dynamic>.from(it),
  ];
}

/// Uploads a Certificate of Employment PDF and returns the `proof` map to
/// store on the experience item. Falls back to base64 in the profile when
/// Cloudinary isn't configured, like the resume upload.
Future<Map<String, dynamic>> uploadEmploymentProofPdf({
  required String fileName,
  required Uint8List bytes,
}) async {
  final now = DateTime.now().toUtc().toIso8601String();
  if (!CloudinaryConfig.isConfigured) {
    return {
      'name': fileName,
      'mimeType': 'application/pdf',
      'data': base64Encode(bytes),
      'size': bytes.length,
      'updatedAt': now,
    };
  }
  final result = await CloudinaryService.uploadEmploymentProof(
    bytes: bytes,
    fileName: fileName,
  );
  return {
    'name': fileName,
    'url': result.secureUrl,
    'publicId': result.publicId,
    'resourceType': result.resourceType,
    'format': result.format,
    'mimeType': 'application/pdf',
    'size': bytes.length,
    'updatedAt': now,
  };
}
