import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
import '../widgets/widgets.dart';
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

Widget _profileAvatar({
  required String avatarUrl,
  double size = 80,
  double radius = 12,
}) {
  final trimmed = avatarUrl.trim();
  final fallback = Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFE5E7EB),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Center(
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: const Color(0xFFD1D5DB),
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  bool _uploadingResume = false;
  bool _uploadingCertification = false;
  String? _error;
  Map<String, dynamic> _user = SessionStore.user ?? {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
        _error = e.toString();
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

  Map<String, dynamic>? _resumeData() {
    final raw = _profileData()['resume'];
    if (raw is! Map) return null;
    final name = (raw['name'] as Object?)?.toString().trim() ?? '';
    final url = (raw['url'] as Object?)?.toString().trim() ?? '';
    final data = (raw['data'] as Object?)?.toString().trim() ?? '';
    final mimeType = (raw['mimeType'] as Object?)?.toString().trim() ?? '';
    final publicId = (raw['publicId'] as Object?)?.toString().trim() ?? '';
    final size = (raw['size'] as num?)?.toInt() ?? 0;
    final updatedAt = (raw['updatedAt'] as Object?)?.toString().trim() ?? '';
    if (name.isEmpty && url.isEmpty && data.isEmpty) return null;
    return {
      'name': name.isNotEmpty ? name : 'Resume',
      'url': url,
      'data': data,
      'mimeType': mimeType,
      'publicId': publicId,
      'size': size,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic>? _certificationData() {
    final raw = _profileData()['certification'];
    if (raw is! Map) return null;
    final name = (raw['name'] as Object?)?.toString().trim() ?? '';
    final url = (raw['url'] as Object?)?.toString().trim() ?? '';
    final data = (raw['data'] as Object?)?.toString().trim() ?? '';
    final mimeType = (raw['mimeType'] as Object?)?.toString().trim() ?? '';
    final publicId = (raw['publicId'] as Object?)?.toString().trim() ?? '';
    final size = (raw['size'] as num?)?.toInt() ?? 0;
    final updatedAt = (raw['updatedAt'] as Object?)?.toString().trim() ?? '';
    if (name.isEmpty && url.isEmpty && data.isEmpty) return null;
    return {
      'name': name.isNotEmpty ? name : 'Certification',
      'url': url,
      'data': data,
      'mimeType': mimeType,
      'publicId': publicId,
      'size': size,
      'updatedAt': updatedAt,
    };
  }

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
    if (stream == null) return null;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<void> _viewDocument(String? url, String? name) async {
    final cleanUrl = url?.trim() ?? '';
    if (cleanUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No web link available for this document.')),
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
      profile.remove('resume');
      final updated = await updateMyProfile({'profile': profile});
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume removed successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove resume: $e')),
      );
    }
  }

  Future<void> _removeCertification() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Certification'),
        content: const Text('Are you sure you want to remove your certification?'),
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
      profile.remove('certification');
      final updated = await updateMyProfile({'profile': profile});
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certification removed successfully.')),
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
          ? 'Upload is too large for the server. Configure Cloudinary in lib/config/cloudinary_config.dart for unlimited fast cloud storage.'
          : 'Upload failed: $message';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendly)));
    } finally {
      if (mounted) setState(() => _uploadingResume = false);
    }
  }

  Future<void> _uploadCertification() async {
    if (_uploadingCertification) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
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
          const SnackBar(
            content: Text('Certification must be 10MB or smaller.'),
          ),
        );
        return;
      }

      setState(() => _uploadingCertification = true);

      final now = DateTime.now().toUtc().toIso8601String();
      final profile = _profileData();

      if (CloudinaryConfig.isConfigured) {
        final result = await CloudinaryService.uploadCertification(
          bytes: bytes,
          fileName: file.name,
        );
        profile['certification'] = {
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
        profile['certification'] = {
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
        const SnackBar(content: Text('Certification uploaded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      final friendly = message.contains('(413)')
          ? 'Upload is too large for the server. Configure Cloudinary in lib/config/cloudinary_config.dart for unlimited fast cloud storage.'
          : 'Upload failed: $message';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendly)));
    } finally {
      if (mounted) setState(() => _uploadingCertification = false);
    }
  }

  Future<void> _openEdit() async {
    final initial = Map<String, dynamic>.from(_user);
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _EditProfileSheet(initial: initial),
    );
    if (res == null) return;
    setState(() {
      _user = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9FAFB),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        // backgroundColor: uses theme
        appBar: AppBar(elevation: 0, title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

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
    final resume = _resumeData();
    final certification = _certificationData();
    final skills = _skills();
    final education = _education();
    final experience = _experience();
    final assessmentResults = _assessmentResults();

    return Scaffold(
      // backgroundColor: uses theme
      appBar: const AppTopBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        height: 72,
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton.filledTonal(
                          onPressed: _openEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                          ),
                          tooltip: 'Edit profile',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: _profileAvatar(
                            avatarUrl: _s('avatarUrl'),
                            radius: 40,
                          ),
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
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          headline.isEmpty ? 'Add a headline' : headline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
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
                            ),
                            _ProfileInfoPill(
                              icon: Icons.email_outlined,
                              label: email.isEmpty ? '—' : email,
                            ),
                            _ProfileInfoPill(
                              icon: Icons.phone_outlined,
                              label: phone.isEmpty ? 'Add phone' : phone,
                            ),
                            _ProfileInfoPill(
                              icon: Icons.link,
                              label: portfolio.isEmpty
                                  ? 'Add portfolio link'
                                  : portfolio,
                              highlight: portfolio.isNotEmpty,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Skills Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Skills',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (skills.isEmpty)
                    _AddInfoButton(label: 'Add skills', onPressed: _openEdit)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: skills.map((s) => _SkillTag(skill: s)).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Skill Assessment Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Skill assessment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (assessmentResults.isNotEmpty)
                        Text(
                          '${assessmentResults.length}/${kAssessmentCategories.length} taken',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textFaint,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    assessmentResults.isEmpty
                        ? 'Find your proficiency level with a short adaptive quiz.'
                        : 'Your assessed proficiency across topics.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (assessmentResults.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: assessmentResults.entries.map((entry) {
                        final category = kAssessmentCategories.firstWhere(
                          (c) => c.key == entry.key,
                          orElse: () => kAssessmentCategories.first,
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${category.label}: ${entry.value.level}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _openAssessment,
                      child: Text(
                        assessmentResults.isEmpty
                            ? 'Take skill assessment'
                            : 'Retake or try another topic',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Experience Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Experience',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  if (experience.isEmpty)
                    _AddInfoButton(
                      label: 'Add experience',
                      onPressed: _openEdit,
                    )
                  else
                    ...experience.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final e = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: idx == experience.length - 1 ? 0 : 16,
                        ),
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
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Education Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Education',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  if (education.isEmpty)
                    _AddInfoButton(label: 'Add education', onPressed: _openEdit)
                  else
                    ...education.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF2563EB),
                                  width: 3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (e['degree'] ?? '').isEmpty
                                        ? '—'
                                        : (e['degree'] ?? ''),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if ((e['school'] ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      e['school'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                  if ((e['years'] ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      e['years'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Resume Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Resume',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (resume != null)
                        TextButton.icon(
                          onPressed: _uploadingResume ? null : _removeResume,
                          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                          label: const Text('Remove', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFE2EF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.description,
                            color: Color(0xFFDC2626),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resume == null
                                  ? 'No resume uploaded yet'
                                  : (resume['name'] ?? 'Resume'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _fileSubtitle(resume),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (resume != null && (resume['url'] as String? ?? '').isNotEmpty)
                        IconButton(
                          tooltip: 'View resume',
                          icon: const Icon(Icons.open_in_new, size: 20, color: Color(0xFF2563EB)),
                          onPressed: () => _viewDocument(resume['url'], resume['name']),
                        ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: _uploadingResume ? null : _uploadResume,
                        child: _uploadingResume
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                resume == null ? 'Upload' : 'Replace',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Certification Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Certification',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (certification != null)
                        TextButton.icon(
                          onPressed: _uploadingCertification ? null : _removeCertification,
                          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                          label: const Text('Remove', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2ECFE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.workspace_premium,
                            color: Color(0xFF2563EB),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              certification == null
                                  ? 'No certification uploaded yet'
                                  : (certification['name'] ?? 'Certification'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _fileSubtitle(
                                certification,
                                fallback: 'PDF, DOC, DOCX, PNG, or JPG (max 10MB)',
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (certification != null && (certification['url'] as String? ?? '').isNotEmpty)
                        IconButton(
                          tooltip: 'View certification',
                          icon: const Icon(Icons.open_in_new, size: 20, color: Color(0xFF2563EB)),
                          onPressed: () => _viewDocument(certification['url'], certification['name']),
                        ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: _uploadingCertification
                            ? null
                            : _uploadCertification,
                        child: _uploadingCertification
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                certification == null ? 'Upload' : 'Replace',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _ProfileInfoPill({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primary : AppColors.textSecondary;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddInfoButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _AddInfoButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillTag extends StatelessWidget {
  final String skill;

  const _SkillTag({required this.skill});

  @override
  Widget build(BuildContext context) {
    return SkillChip(
      label: skill,
      status: SkillChipStatus.neutral,
      size: SkillChipSize.medium,
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> initial;
  const _EditProfileSheet({required this.initial});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _firstName = TextEditingController(
    text: (widget.initial['firstName'] as String?) ?? '',
  );
  late final TextEditingController _lastName = TextEditingController(
    text: (widget.initial['lastName'] as String?) ?? '',
  );
  late final TextEditingController _headline = TextEditingController(
    text: (widget.initial['headline'] as String?) ?? '',
  );
  late final TextEditingController _location = TextEditingController(
    text: (widget.initial['location'] as String?) ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: _phoneDigitsOnly((widget.initial['phone'] as String?) ?? ''),
  );
  late final TextEditingController _portfolio = TextEditingController(
    text: (widget.initial['portfolioUrl'] as String?) ?? '',
  );
  late final TextEditingController _bio = TextEditingController(
    text: (widget.initial['bio'] as String?) ?? '',
  );
  late String _avatarUrl = (widget.initial['avatarUrl'] as String?) ?? '';
  late List<String> _selectedSkills = (() {
    final v = widget.initial['skills'];
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    return <String>[];
  })();
  late final List<String> _initialSkills = List.of(_selectedSkills);
  List<String> _skillOptions = [];
  late final TextEditingController _education = TextEditingController(
    text: (() {
      final v = widget.initial['education'];
      if (v is! List) return '';
      final lines = <String>[];
      for (final it in v) {
        if (it is! Map) continue;
        final degree = (it['degree'] as Object?)?.toString().trim() ?? '';
        final school = (it['school'] as Object?)?.toString().trim() ?? '';
        final years = (it['years'] as Object?)?.toString().trim() ?? '';
        if (degree.isEmpty && school.isEmpty && years.isEmpty) continue;
        lines.add('$degree | $school | $years'.trim());
      }
      return lines.join('\n');
    })(),
  );
  late final TextEditingController _experience = TextEditingController(
    text: (() {
      final v = widget.initial['experience'];
      if (v is! List) return '';
      final lines = <String>[];
      for (final it in v) {
        if (it is! Map) continue;
        final year = (it['year'] as Object?)?.toString().trim() ?? '';
        final title = (it['title'] as Object?)?.toString().trim() ?? '';
        final company = (it['company'] as Object?)?.toString().trim() ?? '';
        final desc = (it['description'] as Object?)?.toString().trim() ?? '';
        if (year.isEmpty && title.isEmpty && company.isEmpty && desc.isEmpty) {
          continue;
        }
        lines.add('$year | $title | $company | $desc'.trim());
      }
      return lines.join('\n');
    })(),
  );

  final _imagePicker = ImagePicker();
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadSkillOptions();
  }

  Future<void> _loadSkillOptions() async {
    try {
      final options = await loadSkillOptions();
      if (!mounted) return;
      setState(() => _skillOptions = options);
    } catch (_) {
      // Skill list failed to load; the picker's search box still works
      // once retried, so fail quietly rather than blocking the form.
    }
  }

  late final Map<String, String> _initialValues = {
    'firstName': _firstName.text,
    'lastName': _lastName.text,
    'headline': _headline.text,
    'location': _location.text,
    'phone': _phone.text,
    'portfolio': _portfolio.text,
    'bio': _bio.text,
    'avatarUrl': _avatarUrl,
    'education': _education.text,
    'experience': _experience.text,
  };

  bool _skillsChanged() {
    final a = List<String>.of(_selectedSkills)..sort();
    final b = List<String>.of(_initialSkills)..sort();
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }

  bool _hasChanges() {
    return _firstName.text != _initialValues['firstName'] ||
        _lastName.text != _initialValues['lastName'] ||
        _headline.text != _initialValues['headline'] ||
        _location.text != _initialValues['location'] ||
        _phone.text != _initialValues['phone'] ||
        _portfolio.text != _initialValues['portfolio'] ||
        _bio.text != _initialValues['bio'] ||
        _avatarUrl != _initialValues['avatarUrl'] ||
        _skillsChanged() ||
        _education.text != _initialValues['education'] ||
        _experience.text != _initialValues['experience'];
  }

  /// Returns true if it's OK to close the sheet now: either nothing
  /// changed, or the user confirmed they want to discard their edits.
  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_hasChanges()) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. If you leave now, they will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  String _mimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _pickAvatar() async {
    if (_saving || _uploadingAvatar) return;
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;

      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (file == null) return;

      setState(() => _uploadingAvatar = true);
      final bytes = await file.readAsBytes();

      if (CloudinaryConfig.isConfigured) {
        final result = await CloudinaryService.uploadProfilePicture(
          bytes: bytes,
          fileName: file.name.isNotEmpty ? file.name : 'avatar.jpg',
        );
        if (!mounted) return;
        setState(() {
          _avatarUrl = result.secureUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar uploaded to Cloudinary!')),
        );
      } else {
        final mimeType = _mimeTypeFromPath(file.path);
        final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';
        if (!mounted) return;
        setState(() {
          _avatarUrl = dataUri;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Avatar upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _headline.dispose();
    _location.dispose();
    _phone.dispose();
    _portfolio.dispose();
    _bio.dispose();
    _education.dispose();
    _experience.dispose();
    super.dispose();
  }

  List<Map<String, String>> _parseEducation(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final out = <Map<String, String>>[];
    for (final line in lines) {
      final parts = line.split('|').map((p) => p.trim()).toList();
      final degree = (parts.isNotEmpty ? parts[0] : '').trim();
      final school = (parts.length > 1 ? parts[1] : '').trim();
      final years = (parts.length > 2 ? parts[2] : '').trim();
      if (degree.isEmpty && school.isEmpty && years.isEmpty) continue;
      out.add({'degree': degree, 'school': school, 'years': years});
    }
    return out;
  }

  List<Map<String, String>> _parseExperience(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final out = <Map<String, String>>[];
    for (final line in lines) {
      final parts = line.split('|').map((p) => p.trim()).toList();
      final year = (parts.isNotEmpty ? parts[0] : '').trim();
      final title = (parts.length > 1 ? parts[1] : '').trim();
      final company = (parts.length > 2 ? parts[2] : '').trim();
      final description = (parts.length > 3 ? parts[3] : '').trim();
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

  Future<void> _save() async {
    if (_saving) return;
    final phoneDigits = _phone.text.trim();
    String phone = '';
    if (phoneDigits.isNotEmpty) {
      if (phoneDigits.length != 10 || !phoneDigits.startsWith('9')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter a valid PH mobile number, e.g. +63 9171234567.',
            ),
          ),
        );
        return;
      }
      phone = '+63$phoneDigits';
    }
    setState(() => _saving = true);
    try {
      final user = await updateMyProfile({
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'headline': _headline.text.trim(),
        'location': _location.text.trim(),
        'phone': phone,
        'portfolioUrl': _portfolio.text.trim(),
        'bio': _bio.text.trim(),
        'avatarUrl': _avatarUrl.trim(),
        'skills': _selectedSkills,
        'education': _parseEducation(_education.text),
        'experience': _parseExperience(_experience.text),
      });
      if (!mounted) return;
      Navigator.pop(context, user);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canClose = await _confirmDiscardIfNeeded();
        if (canClose && context.mounted) Navigator.pop(context);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.maybePop(context),
                        icon: const Icon(Icons.close),
                        tooltip: 'Cancel',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Edit profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _profileAvatar(avatarUrl: _avatarUrl, size: 72, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: (_saving || _uploadingAvatar)
                              ? null
                              : _pickAvatar,
                          icon: _uploadingAvatar
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload),
                          label: Text(
                            _uploadingAvatar
                                ? 'Uploading...'
                                : (_avatarUrl.trim().isEmpty
                                    ? 'Upload photo'
                                    : 'Change photo'),
                          ),
                        ),
                        if (_avatarUrl.trim().isNotEmpty)
                          TextButton(
                            onPressed: (_saving || _uploadingAvatar)
                                ? null
                                : () => setState(() => _avatarUrl = ''),
                            child: const Text('Remove'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstName,
                      decoration: _dec('First name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lastName,
                      decoration: _dec('Last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _headline, decoration: _dec('Headline')),
              const SizedBox(height: 12),
              TextField(controller: _location, decoration: _dec('Location')),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: _dec('Phone').copyWith(prefixText: '+63 '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _portfolio,
                decoration: _dec('Portfolio URL'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Skills',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              _SkillsSelector(
                options: _skillOptions,
                initialSelected: _selectedSkills,
                onChanged: (list) => setState(() => _selectedSkills = list),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _education,
                decoration: _dec(
                  'Education (one per line: Degree | School | Years)',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _experience,
                decoration: _dec(
                  'Experience (one per line: Years | Title | Company | Description)',
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 12),
              TextField(controller: _bio, decoration: _dec('Bio'), maxLines: 4),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the user build up their skills list by picking from a fixed set of
/// [options] instead of typing free text, so profile skills stay in the
/// same vocabulary that job postings are matched against.
class _SkillsSelector extends StatefulWidget {
  final List<String> options;
  final List<String> initialSelected;
  final ValueChanged<List<String>> onChanged;

  const _SkillsSelector({
    required this.options,
    required this.initialSelected,
    required this.onChanged,
  });

  @override
  State<_SkillsSelector> createState() => _SkillsSelectorState();
}

class _SkillsSelectorState extends State<_SkillsSelector> {
  late final List<String> _selected = List.of(widget.initialSelected);
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String skill) {
    setState(() {
      if (!_selected.remove(skill)) _selected.add(skill);
    });
    widget.onChanged(_selected);
  }

  void _addCustom(String skill) {
    final trimmed = skill.trim();
    if (trimmed.isEmpty) return;
    final alreadyHave = _selected.any(
      (s) => s.toLowerCase() == trimmed.toLowerCase(),
    );
    setState(() {
      if (!alreadyHave) _selected.add(trimmed);
      _searchController.clear();
      _query = '';
    });
    widget.onChanged(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = _query.trim();
    final query = trimmedQuery.toLowerCase();
    final available = widget.options
        .where((o) => !_selected.contains(o))
        .where((o) => query.isEmpty || o.toLowerCase().contains(query))
        .take(30)
        .toList();
    final hasExactMatch =
        query.isEmpty ||
        widget.options.any((o) => o.toLowerCase() == query) ||
        _selected.any((s) => s.toLowerCase() == query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selected.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selected
                .map(
                  (s) => InputChip(
                    label: Text(s, style: const TextStyle(fontSize: 13)),
                    onDeleted: () => _toggle(s),
                    backgroundColor: const Color(0xFFDEEEFF),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    labelStyle: const TextStyle(color: Color(0xFF2563EB)),
                    deleteIconColor: const Color(0xFF2563EB),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search or type your own skill',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
          ),
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: _addCustom,
        ),
        if (trimmedQuery.isNotEmpty && !hasExactMatch) ...[
          const SizedBox(height: 8),
          ActionChip(
            avatar: const Icon(Icons.add, size: 16, color: Color(0xFF2563EB)),
            label: Text(
              'Add "$trimmedQuery" as a skill',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => _addCustom(trimmedQuery),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF2563EB)),
          ),
        ],
        const SizedBox(height: 8),
        if (widget.options.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Loading skill list…',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: available.isEmpty
                    ? [
                        Text(
                          trimmedQuery.isEmpty
                              ? 'No matching skills'
                              : 'No matching skills — press enter to add "$trimmedQuery" as a new one',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ]
                    : available
                          .map(
                            (s) => ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: Text(
                                s,
                                style: const TextStyle(fontSize: 13),
                              ),
                              onPressed: () => _toggle(s),
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          )
                          .toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExperienceItem extends StatelessWidget {
  final String year;
  final String title;
  final String company;
  final String description;
  final bool isActive;

  const _ExperienceItem({
    required this.year,
    required this.title,
    required this.company,
    required this.description,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD1D5DB),
                  width: 3,
                ),
              ),
            ),
            Container(
              width: 2,
              height: 100,
              color: const Color(0xFFE5E7EB),
              margin: const EdgeInsets.symmetric(vertical: 4),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                year,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                company,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
