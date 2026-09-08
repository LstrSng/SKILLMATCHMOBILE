import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/cloudinary_config.dart';

/// Represents a successful Cloudinary upload response.
class CloudinaryUploadResult {
  final String secureUrl;
  final String url;
  final String publicId;
  final String resourceType;
  final String format;
  final int bytes;
  final String originalFilename;
  final String createdAt;
  final int? width;
  final int? height;

  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.url,
    required this.publicId,
    required this.resourceType,
    required this.format,
    required this.bytes,
    required this.originalFilename,
    required this.createdAt,
    this.width,
    this.height,
  });

  factory CloudinaryUploadResult.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadResult(
      secureUrl: (json['secure_url'] as Object?)?.toString() ?? '',
      url: (json['url'] as Object?)?.toString() ?? '',
      publicId: (json['public_id'] as Object?)?.toString() ?? '',
      resourceType: (json['resource_type'] as Object?)?.toString() ?? 'auto',
      format: (json['format'] as Object?)?.toString() ?? '',
      bytes: json['bytes'] is num
          ? (json['bytes'] as num).toInt()
          : (int.tryParse(json['bytes']?.toString() ?? '') ?? 0),
      originalFilename: (json['original_filename'] as Object?)?.toString() ?? '',
      createdAt: (json['created_at'] as Object?)?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      width: json['width'] is num
          ? (json['width'] as num).toInt()
          : int.tryParse(json['width']?.toString() ?? ''),
      height: json['height'] is num
          ? (json['height'] as num).toInt()
          : int.tryParse(json['height']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'secureUrl': secureUrl,
        'url': url,
        'publicId': publicId,
        'resourceType': resourceType,
        'format': format,
        'bytes': bytes,
        'originalFilename': originalFilename,
        'createdAt': createdAt,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      };
}

/// Custom exception for Cloudinary operations.
class CloudinaryException implements Exception {
  final String message;
  final int? statusCode;

  const CloudinaryException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Service for uploading media & documents directly to Cloudinary.
class CloudinaryService {
  CloudinaryService._();

  static const Duration _timeout = Duration(seconds: 45);

  /// Formats byte sizes into human-readable strings (e.g. 1.5 MB).
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Resolves the MIME type from file name/extension.
  static MediaType resolveMediaType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (lower.endsWith('.doc')) return MediaType('application', 'msword');
    if (lower.endsWith('.docx')) {
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    }
    return MediaType('application', 'octet-stream');
  }

  /// Uploads raw file bytes to Cloudinary using an unsigned upload preset.
  static Future<CloudinaryUploadResult> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    String? folder,
    String resourceType = 'auto',
    Map<String, String>? extraFields,
  }) async {
    if (!CloudinaryConfig.isConfigured) {
      throw const CloudinaryException(
        'Cloudinary is not configured yet. Please set your Cloud Name and Unsigned Upload Preset in lib/config/cloudinary_config.dart',
      );
    }

    try {
      final uri = CloudinaryConfig.uploadUri(resourceType: resourceType);
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset.trim();
      if (folder != null && folder.trim().isNotEmpty) {
        request.fields['folder'] = folder.trim();
      }
      if (extraFields != null) {
        request.fields.addAll(extraFields);
      }

      final mediaType = resolveMediaType(fileName);
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: mediaType,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          throw const CloudinaryException('Unexpected response from Cloudinary.');
        }
        return CloudinaryUploadResult.fromJson(
          decoded.map((k, v) => MapEntry(k.toString(), v)),
        );
      }

      // Handle Cloudinary error response
      String errorMessage = 'Cloudinary upload failed (${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] is Map) {
          final msg = decoded['error']['message']?.toString().trim();
          if (msg != null && msg.isNotEmpty) {
            errorMessage = msg;
          }
        }
      } catch (_) {}

      throw CloudinaryException(errorMessage, statusCode: response.statusCode);
    } on TimeoutException {
      throw const CloudinaryException(
        'Upload timed out. Please check your internet connection and try again.',
      );
    } on http.ClientException catch (e) {
      throw CloudinaryException(
        'Could not reach Cloudinary server: ${e.message}',
      );
    } catch (e) {
      if (e is CloudinaryException) rethrow;
      throw CloudinaryException('Upload error: $e');
    }
  }

  /// Uploads a user's avatar image to Cloudinary.
  static Future<CloudinaryUploadResult> uploadProfilePicture({
    required Uint8List bytes,
    String fileName = 'avatar.jpg',
  }) async {
    return uploadBytes(
      bytes: bytes,
      fileName: fileName,
      folder: CloudinaryConfig.avatarFolder,
      resourceType: 'image',
    );
  }

  /// Uploads a resume document or image to Cloudinary.
  static Future<CloudinaryUploadResult> uploadResume({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return uploadBytes(
      bytes: bytes,
      fileName: fileName,
      folder: CloudinaryConfig.resumeFolder,
      resourceType: 'auto',
    );
  }

  /// Uploads a certification document or image to Cloudinary.
  static Future<CloudinaryUploadResult> uploadCertification({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return uploadBytes(
      bytes: bytes,
      fileName: fileName,
      folder: CloudinaryConfig.certificationFolder,
      resourceType: 'auto',
    );
  }
}
