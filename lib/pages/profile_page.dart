import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/cloudinary_config.dart';
import '../models/skill_assessment.dart';
import '../services/cloudinary_service.dart';
import '../services/job_roles_data.dart';
import '../services/profile_api.dart';
import '../services/session_store.dart';
import '../services/skill_assessment_bank.dart';
import '../services/skill_assessment_engine.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/widgets.dart';
import 'sign_in_page.dart';
import 'skill_assessment_page.dart';

/// Strips a raw phone value down to the 10-digit PH mobile number
/// (no leading 0 or +63), so it can be shown after a fixed "+63 " prefix.
String _phoneDigitsOnly(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('63') && digits.length > 10) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('0') && digits.length == 11) {
    digits = digits.substring(1);
  }
  return digits;
}

Widget _profileAvatar(
  BuildContext context, {
  required String avatarUrl,
  double size = 80,
  double radius = 12,
  Color? fallbackBg,
  Color? fallbackIconColor,
}) {
  final trimmed = avatarUrl.trim();
  final tokens = context.appColors;
  final fallback = Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: fallbackBg ?? tokens.surfaceMuted,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Center(
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: fallbackIconColor ?? tokens.textFaint,
      ),
    ),
  );

  if (trimmed.isEmpty) return fallback;

  if (trimmed.startsWith('data:image')) {
    final comma = trimmed.indexOf(',');
    if (comma > -1 && comma + 1 < trimmed.length) {
      try {
        final bytes = base64Decode(trimmed.substring(comma + 1));
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        return fallback;
      }
    }
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image.network(
      trimmed,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    ),
  );
}

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
  return {
    'id': id.isNotEmpty ? id : (publicId.isNotEmpty ? publicId : name),
    'name': name.isNotEmpty ? name : fallbackName,
    'url': url,
    'data': data,
    'mimeType': mimeType,
    'publicId': publicId,
    'size': size,
    'updatedAt': updatedAt,
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late bool _loading =
      (SessionStore.user == null || SessionStore.user!.isEmpty);
  bool _uploadingResume = false;
  bool _uploadingCertification = false;
  String? _certUploadStatus;
  String? _error;
  Map<String, dynamic> _user = SessionStore.user ?? {};

  @override
  void initState() {
    super.initState();
    _load(silent: _user.isNotEmpty);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final u = await fetchMyProfile();
      if (!mounted) return;
      setState(() {
        _user = u;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_user.isEmpty) {
          _error = e.toString();
        }
      });
    }
  }

  String _s(String key) => (_user[key] as String?)?.trim() ?? '';
  List<String> _skills() {
    final v = _user['skills'];
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<Map<String, String>> _education() {
    final v = _user['education'];
    if (v is! List) return const [];
    final out = <Map<String, String>>[];
    for (final it in v) {
      if (it is! Map) continue;
      final degree = (it['degree'] as Object?)?.toString().trim() ?? '';
      final school = (it['school'] as Object?)?.toString().trim() ?? '';
      final years = (it['years'] as Object?)?.toString().trim() ?? '';
      if (degree.isEmpty && school.isEmpty && years.isEmpty) continue;
      out.add({'degree': degree, 'school': school, 'years': years});
    }
    return out;
  }

  List<Map<String, String>> _experience() {
    final v = _user['experience'];
    if (v is! List) return const [];
    final out = <Map<String, String>>[];
    for (final it in v) {
      if (it is! Map) continue;
      final year = (it['year'] as Object?)?.toString().trim() ?? '';
      final title = (it['title'] as Object?)?.toString().trim() ?? '';
      final company = (it['company'] as Object?)?.toString().trim() ?? '';
      final description =
          (it['description'] as Object?)?.toString().trim() ?? '';
      if (year.isEmpty &&
          title.isEmpty &&
          company.isEmpty &&
          description.isEmpty) {
        continue;
      }
      out.add({
        'year': year,
        'title': title,
        'company': company,
        'description': description,
      });
    }
    return out;
  }

  Map<String, dynamic> _profileData() {
    final raw = _user['profile'];
    if (raw is! Map) return <String, dynamic>{};
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  Map<String, AssessmentResult> _assessmentResults() =>
      readAssessmentResults(_profileData());

  Future<void> _openAssessment() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SkillAssessmentPage()),
    );
    if (!mounted) return;
    _load();
  }

  Map<String, dynamic>? _resumeData() => readProfileResume(_profileData());

  List<Map<String, dynamic>> _certificationsData() =>
      readProfileCertifications(_profileData());

  String _resumeDateLabel(String raw) {
    if (raw.trim().isEmpty) return 'Uploaded recently';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return 'Uploaded recently';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  String _fileSubtitle(
    Map<String, dynamic>? fileData, {
    String fallback = 'PDF, DOC, DOCX, or Image (max 10MB)',
  }) {
    if (fileData == null) return fallback;
    final parts = <String>[];
    final size = fileData['size'];
    if (size is int && size > 0) {
      parts.add(CloudinaryService.formatFileSize(size));
    }
    final updatedAt = (fileData['updatedAt'] as Object?)?.toString() ?? '';
    if (updatedAt.isNotEmpty) {
      parts.add(_resumeDateLabel(updatedAt));
    }
    return parts.isEmpty ? 'Uploaded recently' : parts.join(' • ');
  }

  String _resumeMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  Future<Uint8List?> _resumeBytesFromPick(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    final stream = file.readStream;
    if (stream != null) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }
    if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
      try {
        final f = File(file.path!);
        if (await f.exists()) {
          return await f.readAsBytes();
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _viewDocument(String? url, String? name) async {
    final cleanUrl = url?.trim() ?? '';
    if (cleanUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No web link available for this document.'),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(cleanUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${name ?? 'document'}.')),
      );
    }
  }

  Future<void> _viewResumeFile(Map<String, dynamic> doc) async {
    final url = (doc['url'] as String? ?? '').trim();
    final name = (doc['name'] as String? ?? 'Document').trim();
    if (url.isNotEmpty) {
      await _viewDocument(url, name);
      return;
    }

    final data = (doc['data'] as String? ?? '').trim();
    if (data.isNotEmpty) {
      final mimeType = (doc['mimeType'] as String? ?? '').toLowerCase();
      if (mimeType.startsWith('image/')) {
        try {
          final bytes = base64Decode(data);
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(name),
              content: InteractiveViewer(child: Image.memory(bytes)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
          return;
        } catch (_) {}
      }

      final size = doc['size'] != null
          ? '${((doc['size'] as num) / 1024).toStringAsFixed(1)} KB'
          : 'Uploaded document';
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.description, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File type: ${mimeType.isNotEmpty ? mimeType : "PDF Document"}',
              ),
              const SizedBox(height: 6),
              Text('File size: $size'),
              const SizedBox(height: 12),
              Text(
                'This document is stored securely in your SkillMatch profile and shared directly with employers when you apply.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No document data available to view.')),
    );
  }

  Future<void> _removeResume() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Resume'),
        content: const Text('Are you sure you want to remove your resume?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final profile = _profileData();
      profile['resume'] = null;
      final updated = await updateMyProfile({
        'profile': profile,
        'removeResume': true,
      });
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume removed successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove resume: $e')));
    }
  }

  Future<void> _removeCertification(int index) async {
    final certs = _certificationsData();
    if (index < 0 || index >= certs.length) return;
    final cert = certs[index];
    final certName = (cert['name'] as String? ?? '').isNotEmpty
        ? cert['name']
        : 'Certification ${index + 1}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Certification'),
        content: Text('Are you sure you want to remove "$certName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final profile = _profileData();
      final updatedList = List<Map<String, dynamic>>.from(
        _certificationsData(),
      );
      if (index < updatedList.length) {
        updatedList.removeAt(index);
      }
      profile['certifications'] = updatedList;
      if (updatedList.isNotEmpty) {
        profile['certification'] = updatedList.first;
      } else {
        profile['certification'] = null;
      }

      final updated = await updateMyProfile({'profile': profile});
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Certification "$certName" removed successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove certification: $e')),
      );
    }
  }

  Future<void> _uploadResume() async {
    if (_uploadingResume) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
        withData: true,
        withReadStream: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      final ext = (file.extension ?? '').toLowerCase();
      const allowed = {'pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'};
      if (!allowed.contains(ext)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please choose a PDF, DOC, DOCX, or Image file.'),
          ),
        );
        return;
      }
      final bytes = await _resumeBytesFromPick(file);
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read selected file.')),
        );
        return;
      }

      const maxBytes = 10 * 1024 * 1024; // 10MB
      if (bytes.length > maxBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resume must be 10MB or smaller.')),
        );
        return;
      }

      setState(() => _uploadingResume = true);

      final now = DateTime.now().toUtc().toIso8601String();
      final profile = _profileData();

      if (CloudinaryConfig.isConfigured) {
        final result = await CloudinaryService.uploadResume(
          bytes: bytes,
          fileName: file.name,
        );
        profile['resume'] = {
          'name': file.name,
          'url': result.secureUrl,
          'publicId': result.publicId,
          'resourceType': result.resourceType,
          'format': result.format,
          'mimeType': _resumeMimeType(file.name),
          'size': bytes.length,
          'updatedAt': now,
        };
      } else {
        // Fallback to base64 encoding if Cloudinary is not configured yet
        profile['resume'] = {
          'name': file.name,
          'mimeType': _resumeMimeType(file.name),
          'data': base64Encode(bytes),
          'size': bytes.length,
          'updatedAt': now,
        };
      }

      final updated = await updateMyProfile({'profile': profile});
      if (!mounted) return;
      setState(() {
        _user = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume uploaded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      final friendly = message.contains('(413)')
          ? 'Upload failed: File is too large.'
          : 'Upload failed: $message';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendly)));
    } finally {
      if (mounted) setState(() => _uploadingResume = false);
    }
  }

  Future<void> _uploadCertifications() async {
    if (_uploadingCertification) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
        allowMultiple: true,
        withData: true,
        withReadStream: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      const allowed = {'pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'};
      const maxBytes = 10 * 1024 * 1024; // 10MB per file

      final validFiles = <PlatformFile>[];
      final invalidExtFiles = <String>[];
      final oversizedFiles = <String>[];

      for (final file in picked.files) {
        final ext = (file.extension ?? '').toLowerCase();
        if (!allowed.contains(ext)) {
          invalidExtFiles.add(file.name);
          continue;
        }
        if (file.size > maxBytes) {
          oversizedFiles.add(file.name);
          continue;
        }
        validFiles.add(file);
      }

      if (invalidExtFiles.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Skipped unsupported files: ${invalidExtFiles.join(", ")}. Please use PDF, DOC, DOCX, PNG, or JPG.',
            ),
          ),
        );
      }

      if (oversizedFiles.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Skipped files larger than 10MB: ${oversizedFiles.join(", ")}.',
            ),
          ),
        );
      }

      if (validFiles.isEmpty) return;

      setState(() {
        _uploadingCertification = true;
        _certUploadStatus =
            'Uploading ${validFiles.length} file${validFiles.length == 1 ? "" : "s"}...';
      });

      final uploadedItems = <Map<String, dynamic>>[];
      final now = DateTime.now().toUtc().toIso8601String();

      for (var i = 0; i < validFiles.length; i++) {
        final file = validFiles[i];
        if (validFiles.length > 1 && mounted) {
          setState(() {
            _certUploadStatus = 'Uploading ${i + 1} of ${validFiles.length}...';
          });
        }

        final bytes = await _resumeBytesFromPick(file);
        if (bytes == null) continue;
        if (bytes.length > maxBytes) continue;

        final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_$i';

        if (CloudinaryConfig.isConfigured) {
          final result = await CloudinaryService.uploadCertification(
            bytes: bytes,
            fileName: file.name,
          );
          uploadedItems.add({
            'id': uniqueId,
            'name': file.name,
            'url': result.secureUrl,
            'publicId': result.publicId,
            'resourceType': result.resourceType,
            'format': result.format,
            'mimeType': _resumeMimeType(file.name),
            'size': bytes.length,
            'updatedAt': now,
          });
        } else {
          // Fallback to base64 encoding if Cloudinary is not configured yet
          uploadedItems.add({
            'id': uniqueId,
            'name': file.name,
            'mimeType': _resumeMimeType(file.name),
            'data': base64Encode(bytes),
            'size': bytes.length,
            'updatedAt': now,
          });
        }
      }

      if (uploadedItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No files were successfully uploaded.'),
            ),
          );
        }
        return;
      }

      final profile = _profileData();
      final currentList = _certificationsData();
      final updatedList = [...currentList, ...uploadedItems];
      profile['certifications'] = updatedList;
      if (updatedList.isNotEmpty) {
        profile['certification'] = updatedList.first;
      }

      final updated = await updateMyProfile({'profile': profile});
      if (!mounted) return;
      setState(() {
        _user = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uploadedItems.length == 1
                ? 'Certification uploaded successfully.'
                : '${uploadedItems.length} certifications uploaded successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      final friendly = message.contains('(413)')
          ? 'Upload failed: File is too large.'
          : 'Upload failed: $message';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendly)));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingCertification = false;
          _certUploadStatus = null;
        });
      }
    }
  }

  Future<void> _openEdit() async {
    final initial = Map<String, dynamic>.from(_user);
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => EditProfileSheet(initial: initial),
    );
    if (res == null) return;
    setState(() {
      _user = res;
    });
  }

  Future<void> _quickPickAvatar() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.appColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Change Profile Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ctx.appColors.textPrimary,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera, color: ctx.appColors.primary),
              title: Text(
                'Take Photo',
                style: TextStyle(color: ctx.appColors.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: ctx.appColors.primary),
              title: Text(
                'Choose from Gallery',
                style: TextStyle(color: ctx.appColors.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      String newAvatarUrl;

      if (CloudinaryConfig.isConfigured) {
        final result = await CloudinaryService.uploadProfilePicture(
          bytes: bytes,
          fileName: file.name.isNotEmpty ? file.name : 'avatar.jpg',
        );
        newAvatarUrl = result.secureUrl;
      } else {
        final ext = (file.name.split('.').lastOrNull ?? 'jpg').toLowerCase();
        final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        newAvatarUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      }

      final updated = await updateMyProfile({'avatarUrl': newAvatarUrl});
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
    }
  }

  Future<void> _launchUrlString(String rawUrl) async {
    var url = rawUrl.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not open link: $url')));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open link: $e')));
      }
    }
  }

  Future<void> _launchEmail(String email) async {
    final clean = email.trim();
    if (clean.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch email app for $clean')),
        );
      }
    } catch (_) {}
  }

  Future<void> _launchPhone(String phone) async {
    final digits = _phoneDigitsOnly(phone);
    if (digits.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: '+63$digits');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch phone app for +63 $digits')),
        );
      }
    } catch (_) {}
  }

  int _calculateProfileCompletion({
    required String firstName,
    required String lastName,
    required String headline,
    required String location,
    required String phone,
    required String email,
    required String portfolio,
    required List<String> skills,
    required Map<String, dynamic>? resume,
    required List<Map<String, dynamic>> certifications,
    required List<Map<String, String>> experience,
    required List<Map<String, String>> education,
    required Map<String, AssessmentResult> assessments,
    required String avatarUrl,
  }) {
    var score = 0;
    // 1. Basic Info (25%)
    if (firstName.isNotEmpty && lastName.isNotEmpty) score += 10;
    if (headline.isNotEmpty) score += 5;
    if (location.isNotEmpty) score += 5;
    if (phone.isNotEmpty || email.isNotEmpty) score += 5;

    // 2. Avatar (5%)
    if (avatarUrl.isNotEmpty) score += 5;

    // 3. Skills (20%)
    if (skills.length >= 3) {
      score += 20;
    } else if (skills.isNotEmpty) {
      score += 10;
    }

    // 4. Resume (20%)
    if (resume != null) score += 20;

    // 5. Experience (10%)
    if (experience.isNotEmpty) score += 10;

    // 6. Education (10%)
    if (education.isNotEmpty) score += 10;

    // 7. Certifications or Assessments (10%)
    if (certifications.isNotEmpty || assessments.isNotEmpty) {
      score += 10;
    }

    return score.clamp(0, 100);
  }

  Map<String, String> _getCompletionTip({
    required Map<String, dynamic>? resume,
    required List<String> skills,
    required String headline,
    required List<Map<String, String>> experience,
    required List<Map<String, String>> education,
    required Map<String, AssessmentResult> assessments,
    required List<Map<String, dynamic>> certifications,
    required String avatarUrl,
  }) {
    if (resume == null) {
      return {
        'action': 'Upload Resume',
        'tip': 'Upload your resume (+20%) to unlock 1-click job applications.',
        'target': 'resume',
      };
    }
    if (skills.length < 3) {
      return {
        'action': 'Add Skills',
        'tip':
            'Add 3 or more skills (+10-20%) to optimize AI job recommendations.',
        'target': 'skills',
      };
    }
    if (headline.isEmpty) {
      return {
        'action': 'Add Headline',
        'tip':
            'Add a professional headline (+5%) so employers recognize your specialty.',
        'target': 'headline',
      };
    }
    if (experience.isEmpty) {
      return {
        'action': 'Add Experience',
        'tip':
            'Add your work experience (+10%) to highlight career accomplishments.',
        'target': 'experience',
      };
    }
    if (education.isEmpty) {
      return {
        'action': 'Add Education',
        'tip':
            'Add your academic background (+10%) to complete your credentials.',
        'target': 'education',
      };
    }
    if (assessments.isEmpty && certifications.isEmpty) {
      return {
        'action': 'Take Assessment',
        'tip':
            'Take a quick skill assessment (+10%) to earn verified skill badges.',
        'target': 'assessment',
      };
    }
    if (avatarUrl.isEmpty) {
      return {
        'action': 'Add Photo',
        'tip': 'Upload a profile photo (+5%) to make your profile stand out.',
        'target': 'avatar',
      };
    }
    return {
      'action': 'All Complete!',
      'tip':
          'Your profile is outstanding! You qualify for top-tier job matches.',
      'target': 'complete',
    };
  }

  void _handleTipAction(String target) {
    switch (target) {
      case 'resume':
        if (!_uploadingResume) _uploadResume();
        break;
      case 'skills':
      case 'headline':
      case 'experience':
      case 'education':
        _openEdit();
        break;
      case 'assessment':
        _openAssessment();
        break;
      case 'avatar':
        _quickPickAvatar();
        break;
      default:
        _openEdit();
    }
  }

  Widget _buildFileIcon(
    Map<String, dynamic>? fileData, {
    required bool isDark,
    required AppThemeExtension tokens,
  }) {
    final name = (fileData?['name'] as String? ?? '').toLowerCase();
    Color iconColor;
    Color bgColor;
    IconData icon;

    if (name.endsWith('.pdf')) {
      icon = Icons.picture_as_pdf_rounded;
      iconColor = isDark ? AppColors.dangerLight : AppColors.danger;
      bgColor = isDark ? const Color(0xFF3B1212) : const Color(0xFFFEE2E2);
    } else if (name.endsWith('.doc') || name.endsWith('.docx')) {
      icon = Icons.description_rounded;
      iconColor = isDark ? AppColors.infoLight : AppColors.info;
      bgColor = isDark ? AppColors.infoDarkBg : AppColors.infoBg;
    } else if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      icon = Icons.image_rounded;
      iconColor = isDark ? AppColors.successLight : AppColors.success;
      bgColor = isDark ? AppColors.successDarkBg : AppColors.successBg;
    } else {
      icon = Icons.insert_drive_file_rounded;
      iconColor = tokens.primary;
      bgColor = tokens.primarySoftBg;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: Icon(icon, color: iconColor, size: 22)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.appColors.scaffoldBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(elevation: 0, title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                if (SessionStore.token == null || SessionStore.token!.isEmpty)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const SignInPage()),
                        (_) => false,
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In Again'),
                  )
                else
                  FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final tokens = context.appColors;
    final isDark = context.isDarkMode;
    final firstName = _s('firstName');
    final lastName = _s('lastName');
    final fullName = ('$firstName $lastName').trim().isEmpty
        ? 'Your name'
        : ('$firstName $lastName').trim();
    final headline = _s('headline');
    final location = _s('location');
    final email = _s('email');
    final phone = _s('phone');
    final portfolio = _s('portfolioUrl');
    final avatarUrl = _s('avatarUrl');
    final resume = _resumeData();
    final certifications = _certificationsData();
    final skills = _skills();
    final skillLevels = readSkillLevels(_user);
    final education = _education();
    final experience = _experience();
    final assessmentResults = _assessmentResults();

    final completionScore = _calculateProfileCompletion(
      firstName: firstName,
      lastName: lastName,
      headline: headline,
      location: location,
      phone: phone,
      email: email,
      portfolio: portfolio,
      skills: skills,
      resume: resume,
      certifications: certifications,
      experience: experience,
      education: education,
      assessments: assessmentResults,
      avatarUrl: avatarUrl,
    );

    final completionTip = _getCompletionTip(
      resume: resume,
      skills: skills,
      headline: headline,
      experience: experience,
      education: education,
      assessments: assessmentResults,
      certifications: certifications,
      avatarUrl: avatarUrl,
    );

    return Scaffold(
      appBar: const AppTopBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Profile Header Card
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: tokens.primaryGradient,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: FilledButton.tonalIcon(
                          onPressed: _openEdit,
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: const Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark
                                ? tokens.cardBackground.withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.9),
                            foregroundColor: tokens.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: tokens.cardBackground,
                                shape: BoxShape.circle,
                                boxShadow: tokens.cardShadows,
                              ),
                              child: _profileAvatar(
                                context,
                                avatarUrl: avatarUrl,
                                size: 88,
                                radius: 44,
                                fallbackBg: tokens.surfaceMuted,
                                fallbackIconColor: tokens.textSecondary,
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _quickPickAvatar,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: tokens.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: tokens.cardBackground,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      children: [
                        Text(
                          fullName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (headline.isNotEmpty)
                          Text(
                            headline,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: tokens.textSecondary,
                            ),
                          )
                        else
                          InkWell(
                            onTap: _openEdit,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: Text(
                                '+ Add professional headline',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.primary,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ProfileInfoPill(
                              icon: Icons.location_on_outlined,
                              label: location.isEmpty
                                  ? 'Add location'
                                  : location,
                              isPrompt: location.isEmpty,
                              onTap: _openEdit,
                            ),
                            _ProfileInfoPill(
                              icon: Icons.email_outlined,
                              label: email.isEmpty ? 'Add email' : email,
                              isPrompt: email.isEmpty,
                              onTap: email.isEmpty
                                  ? _openEdit
                                  : () => _launchEmail(email),
                            ),
                            _ProfileInfoPill(
                              icon: Icons.phone_outlined,
                              label: phone.isEmpty
                                  ? 'Add phone'
                                  : '+63 ${_phoneDigitsOnly(phone)}',
                              isPrompt: phone.isEmpty,
                              onTap: phone.isEmpty
                                  ? _openEdit
                                  : () => _launchPhone(phone),
                            ),
                            _ProfileInfoPill(
                              icon: Icons.link,
                              label: portfolio.isEmpty
                                  ? 'Add portfolio link'
                                  : portfolio,
                              highlight: portfolio.isNotEmpty,
                              isPrompt: portfolio.isEmpty,
                              onTap: portfolio.isEmpty
                                  ? _openEdit
                                  : () => _launchUrlString(portfolio),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Profile Strength Meter Card
            _ProfileStrengthCard(
              percentage: completionScore,
              tip: completionTip,
              onAction: () =>
                  _handleTipAction(completionTip['target'] ?? 'edit'),
            ),
            const SizedBox(height: 16),

            // Skills Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileSectionHeader(
                    icon: Icons.psychology_outlined,
                    title: 'Skills',
                    badgeText: skills.isNotEmpty ? '${skills.length}' : null,
                    actionLabel: 'Edit',
                    actionIcon: Icons.edit_outlined,
                    onAction: _openEdit,
                  ),
                  const SizedBox(height: 16),
                  if (skills.isEmpty)
                    _ProfileEmptyState(
                      icon: Icons.psychology_outlined,
                      title: 'No skills added yet',
                      subtitle:
                          'Add your core skills to unlock accurate AI job recommendations and compatibility scoring.',
                      buttonLabel: 'Add Skills',
                      onAction: _openEdit,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...skills.map((s) {
                          final isVerified = assessmentResults.values.any(
                            (res) =>
                                res.passed &&
                                ((res.roleTitle?.toLowerCase().contains(
                                          s.toLowerCase(),
                                        ) ??
                                        false) ||
                                    (s.toLowerCase().contains(
                                      res.roleTitle?.toLowerCase() ?? '___',
                                    ))),
                          );
                          return _SkillTag(
                            skill: s,
                            level: skillLevels[s],
                            isVerified: isVerified,
                          );
                        }),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _openEdit,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.surfaceMuted,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: tokens.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 14,
                                    color: tokens.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Add more',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Skill Assessment Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileSectionHeader(
                    icon: Icons.verified_outlined,
                    iconColor: tokens.verified,
                    iconBg: isDark
                        ? AppColors.verifiedDarkSoft
                        : AppColors.verifiedSoft,
                    title: 'Skill Assessment',
                    badgeText: assessmentResults.isNotEmpty
                        ? '${assessmentResults.length}/${kAssessmentCategories.length} Verified'
                        : null,
                    badgeColor: tokens.verified,
                    actionLabel: assessmentResults.isEmpty
                        ? 'Take Quiz'
                        : 'Retake',
                    actionIcon: Icons.play_arrow_rounded,
                    onAction: _openAssessment,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    assessmentResults.isEmpty
                        ? 'Benchmark your technical abilities with adaptive quizzes and earn verified badges on your profile.'
                        : 'Your validated skill proficiencies and verified benchmark scores.',
                    style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  if (assessmentResults.isEmpty)
                    _ProfileEmptyState(
                      icon: Icons.workspace_premium_outlined,
                      title: 'No assessments completed',
                      subtitle:
                          'Take a 5-minute quiz to prove your skills and earn a verified badge for employers.',
                      buttonLabel: 'Start Assessment',
                      onAction: _openAssessment,
                    )
                  else ...[
                    Column(
                      children: assessmentResults.entries.map((entry) {
                        final res = entry.value;
                        final category = kAssessmentCategories.firstWhere(
                          (c) => c.key == entry.key,
                          orElse: () => AssessmentCategory(
                            key: entry.key,
                            label: res.roleTitle ?? entry.key,
                            description: '',
                            questions: const [],
                          ),
                        );
                        final label = res.roleTitle?.isNotEmpty == true
                            ? res.roleTitle!
                            : category.label;
                        final statusBg = res.passed
                            ? (isDark
                                  ? AppColors.successDarkBg
                                  : AppColors.successBg)
                            : (isDark
                                  ? AppColors.warningDarkBg
                                  : AppColors.warningBg);
                        final statusColor = res.passed
                            ? (isDark
                                  ? AppColors.successLight
                                  : AppColors.success)
                            : (isDark
                                  ? AppColors.warningLight
                                  : AppColors.warning);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tokens.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tokens.cardBorderSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      res.passed
                                          ? Icons.verified_rounded
                                          : Icons.pending_actions_rounded,
                                      size: 18,
                                      color: statusColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: tokens.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${res.level} • Recorded ${res.formattedDateOnly}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: tokens.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${res.scorePercentage}%',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: res.scorePercentage / 100.0,
                                  minHeight: 4,
                                  backgroundColor: isDark
                                      ? AppColors.darkSurfaceMuted
                                      : const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openAssessment,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retake or Try Another Topic'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.primary,
                          side: BorderSide(color: tokens.cardBorder),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Experience Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileSectionHeader(
                    icon: Icons.work_outline_rounded,
                    title: 'Experience',
                    badgeText: experience.isNotEmpty
                        ? '${experience.length} ${experience.length == 1 ? "Role" : "Roles"}'
                        : null,
                    actionLabel: 'Add',
                    actionIcon: Icons.add,
                    onAction: _openEdit,
                  ),
                  const SizedBox(height: 16),
                  if (experience.isEmpty)
                    _ProfileEmptyState(
                      icon: Icons.work_outline_rounded,
                      title: 'No work experience added',
                      subtitle:
                          'Highlight your past roles, internships, or freelance projects.',
                      buttonLabel: 'Add Experience',
                      onAction: _openEdit,
                    )
                  else
                    ...experience.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final e = entry.value;
                      final isLast = idx == experience.length - 1;
                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                        child: _ExperienceItem(
                          year: (e['year'] ?? '').isEmpty
                              ? '—'
                              : (e['year'] ?? ''),
                          title: (e['title'] ?? '').isEmpty
                              ? '—'
                              : (e['title'] ?? ''),
                          company: (e['company'] ?? '').isEmpty
                              ? '—'
                              : (e['company'] ?? ''),
                          description: e['description'] ?? '',
                          isActive: idx == 0,
                          isLast: isLast,
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Education Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileSectionHeader(
                    icon: Icons.school_outlined,
                    title: 'Education',
                    badgeText: education.isNotEmpty
                        ? '${education.length}'
                        : null,
                    actionLabel: 'Add',
                    actionIcon: Icons.add,
                    onAction: _openEdit,
                  ),
                  const SizedBox(height: 16),
                  if (education.isEmpty)
                    _ProfileEmptyState(
                      icon: Icons.school_outlined,
                      title: 'No education added',
                      subtitle:
                          'Add your degree, vocational diploma, or high school education.',
                      buttonLabel: 'Add Education',
                      onAction: _openEdit,
                    )
                  else
                    ...education.map((e) {
                      final degree = (e['degree'] ?? '').isEmpty
                          ? 'Degree / Program'
                          : (e['degree'] ?? '');
                      final school = e['school'] ?? '';
                      final years = e['years'] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tokens.cardBorderSoft),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tokens.primarySoftBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.school,
                                size: 18,
                                color: tokens.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    degree,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  if (school.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      school,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (years.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.cardBackground,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: tokens.cardBorderSoft,
                                        ),
                                      ),
                                      child: Text(
                                        years,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: tokens.textFaint,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Resume Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileSectionHeader(
                    icon: Icons.description_outlined,
                    iconColor: isDark
                        ? AppColors.dangerLight
                        : AppColors.danger,
                    iconBg: isDark
                        ? const Color(0xFF3B1212)
                        : const Color(0xFFFEE2E2),
                    title: 'Resume',
                    badgeText: resume != null ? 'Active' : 'Missing',
                    badgeColor: resume != null
                        ? (isDark ? AppColors.successDarkBg : AppColors.success)
                        : (isDark
                              ? AppColors.warningDarkBg
                              : AppColors.warning),
                    actionLabel: resume != null ? 'Replace' : 'Upload',
                    actionIcon: Icons.upload_file,
                    onAction: _uploadingResume ? null : _uploadResume,
                  ),
                  const SizedBox(height: 16),
                  if (resume == null)
                    _ProfileEmptyState(
                      icon: Icons.upload_file_rounded,
                      title: 'No resume uploaded yet',
                      subtitle:
                          'PDF, DOC, DOCX, PNG, or JPG (max 10MB). Shared with employers when applying.',
                      buttonLabel: 'Upload Resume',
                      onAction: _uploadingResume ? () {} : _uploadResume,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tokens.cardBorderSoft),
                      ),
                      child: Row(
                        children: [
                          _buildFileIcon(
                            resume,
                            isDark: isDark,
                            tokens: tokens,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  resume['name'] ?? 'Resume',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _fileSubtitle(resume),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if ((resume['url'] as String? ?? '').isNotEmpty ||
                              (resume['data'] as String? ?? '').isNotEmpty)
                            IconButton(
                              tooltip: 'View resume',
                              icon: Icon(
                                Icons.open_in_new,
                                size: 20,
                                color: tokens.primary,
                              ),
                              onPressed: () => _viewResumeFile(resume),
                            ),
                          IconButton(
                            tooltip: 'Remove resume',
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: isDark
                                  ? AppColors.dangerLight
                                  : AppColors.danger,
                            ),
                            onPressed: _uploadingResume ? null : _removeResume,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Certifications Section (Supports multiple files)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileSectionHeader(
                    icon: Icons.workspace_premium_outlined,
                    iconColor: isDark
                        ? AppColors.warningLight
                        : AppColors.warning,
                    iconBg: isDark
                        ? AppColors.warningDarkBg
                        : AppColors.warningBg,
                    title: 'Certifications',
                    badgeText: certifications.isNotEmpty
                        ? '${certifications.length}'
                        : null,
                    actionLabel: certifications.isNotEmpty
                        ? 'Add Files'
                        : 'Upload',
                    actionIcon: Icons.add,
                    onAction: _uploadingCertification
                        ? null
                        : _uploadCertifications,
                  ),
                  const SizedBox(height: 16),
                  if (_uploadingCertification) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _certUploadStatus ?? 'Uploading certifications...',
                            style: TextStyle(
                              fontSize: 13,
                              color: tokens.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (certifications.isEmpty)
                    _ProfileEmptyState(
                      icon: Icons.workspace_premium_outlined,
                      title: 'No certifications uploaded',
                      subtitle:
                          'Upload TESDA, TVET, or global certificates to verify your expertise and boost match score.',
                      buttonLabel: 'Upload Certification',
                      onAction: _uploadingCertification
                          ? () {}
                          : _uploadCertifications,
                    )
                  else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: certifications.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final cert = certifications[index];
                        final certUrl = (cert['url'] as String? ?? '').trim();
                        final certName =
                            cert['name'] ?? 'Certification ${index + 1}';
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tokens.surfaceMuted,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: tokens.cardBorderSoft),
                          ),
                          child: Row(
                            children: [
                              _buildFileIcon(
                                cert,
                                isDark: isDark,
                                tokens: tokens,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      certName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _fileSubtitle(
                                        cert,
                                        fallback: 'PDF, DOC, DOCX, PNG, or JPG',
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (certUrl.isNotEmpty ||
                                  (cert['data'] as String? ?? '').isNotEmpty)
                                IconButton(
                                  tooltip: 'View certification',
                                  icon: Icon(
                                    Icons.open_in_new,
                                    size: 20,
                                    color: tokens.primary,
                                  ),
                                  onPressed: () => _viewResumeFile(cert),
                                ),
                              IconButton(
                                tooltip: 'Remove certification',
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: isDark
                                      ? AppColors.dangerLight
                                      : AppColors.danger,
                                ),
                                onPressed: _uploadingCertification
                                    ? null
                                    : () => _removeCertification(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _uploadingCertification
                            ? null
                            : _uploadCertifications,
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Add More Certifications'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.primary,
                          side: BorderSide(color: tokens.cardBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _ProfileSectionHeader extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBg;
  final String title;
  final String? badgeText;
  final Color? badgeColor;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _ProfileSectionHeader({
    required this.icon,
    required this.title,
    this.iconColor,
    this.iconBg,
    this.badgeText,
    this.badgeColor,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final primaryColor = iconColor ?? tokens.primary;
    final bgColor = iconBg ?? tokens.primarySoftBg;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Icon(icon, size: 18, color: primaryColor)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              if (badgeText != null && badgeText!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor ?? tokens.primarySoftBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor != null ? Colors.white : tokens.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onAction != null && (actionLabel != null || actionIcon != null))
          TextButton.icon(
            onPressed: onAction,
            icon: Icon(
              actionIcon ?? Icons.edit_outlined,
              size: 14,
              color: tokens.primary,
            ),
            label: Text(
              actionLabel ?? 'Edit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.primary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }
}

class _ProfileStrengthCard extends StatelessWidget {
  final int percentage;
  final Map<String, String> tip;
  final VoidCallback onAction;

  const _ProfileStrengthCard({
    required this.percentage,
    required this.tip,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final isDark = context.isDarkMode;

    String level;
    Color levelColor;
    Color levelBg;
    if (percentage >= 85) {
      level = 'All-Star';
      levelColor = isDark ? AppColors.successLight : AppColors.success;
      levelBg = isDark ? AppColors.successDarkBg : AppColors.successBg;
    } else if (percentage >= 50) {
      level = 'Intermediate';
      levelColor = isDark ? AppColors.primaryLight : AppColors.primary;
      levelBg = tokens.primarySoftBg;
    } else {
      level = 'Beginner';
      levelColor = isDark ? AppColors.warningLight : AppColors.warning;
      levelBg = isDark ? AppColors.warningDarkBg : AppColors.warningBg;
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tokens.primarySoftBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.insights_rounded,
                      size: 16,
                      color: tokens.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Profile Strength',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: levelBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$level • $percentage%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: levelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage / 100.0,
              minHeight: 8,
              backgroundColor: tokens.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
            ),
          ),
          if (percentage < 100 && (tip['tip'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.cardBorderSoft),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: tokens.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip['tip'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      tip['action'] ?? 'Complete',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onAction;

  const _ProfileEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorderSoft),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.cardBorderSoft),
            ),
            child: Icon(icon, size: 24, color: tokens.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add, size: 14),
            label: Text(buttonLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.primary,
              side: BorderSide(color: tokens.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final bool isPrompt;
  final VoidCallback? onTap;

  const _ProfileInfoPill({
    required this.icon,
    required this.label,
    this.highlight = false,
    this.isPrompt = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final color = highlight
        ? tokens.primary
        : (isPrompt ? tokens.textFaint : tokens.textSecondary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          decoration: BoxDecoration(
            color: tokens.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPrompt
                  ? tokens.primary.withValues(alpha: 0.25)
                  : tokens.cardBorderSoft,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: isPrompt ? FontWeight.w400 : FontWeight.w500,
                    fontStyle: isPrompt ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              if (onTap != null &&
                  !isPrompt &&
                  (highlight ||
                      icon == Icons.email_outlined ||
                      icon == Icons.phone_outlined)) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_outward,
                  size: 11,
                  color: color.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillTag extends StatelessWidget {
  final String skill;
  final int? level;
  final bool isVerified;

  const _SkillTag({required this.skill, this.level, this.isVerified = false});

  @override
  Widget build(BuildContext context) {
    return SkillChip(
      label: level == null ? skill : '$skill · $level/10',
      tooltip: level == null ? null : '${skillLevelLabel(level!)} ($level/10)',
      status: isVerified ? SkillChipStatus.verified : SkillChipStatus.neutral,
      isVerified: isVerified,
      size: SkillChipSize.medium,
    );
  }
}

class _ExperienceItem extends StatelessWidget {
  final String year;
  final String title;
  final String company;
  final String description;
  final bool isActive;
  final bool isLast;

  const _ExperienceItem({
    required this.year,
    required this.title,
    required this.company,
    required this.description,
    required this.isActive,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isActive ? tokens.primary : tokens.surfaceMuted,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? tokens.primary : tokens.cardBorder,
                    width: 2.5,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: tokens.cardBorderSoft,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.primarySoftBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Latest',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: tokens.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 13,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        company,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: tokens.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (year.isNotEmpty && year != '—') ...[
                      const SizedBox(width: 6),
                      Text('•', style: TextStyle(color: tokens.textFaint)),
                      const SizedBox(width: 6),
                      Text(
                        year,
                        style: TextStyle(fontSize: 12, color: tokens.textFaint),
                      ),
                    ],
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
