import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'settings_page.dart';
import '../services/profile_api.dart';
import '../services/session_store.dart';

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
    if (v is List)
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
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
          description.isEmpty)
        continue;
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

  Map<String, String>? _resumeData() {
    final raw = _profileData()['resume'];
    if (raw is! Map) return null;
    final name = (raw['name'] as Object?)?.toString().trim() ?? '';
    final mimeType = (raw['mimeType'] as Object?)?.toString().trim() ?? '';
    final data = (raw['data'] as Object?)?.toString().trim() ?? '';
    final updatedAt = (raw['updatedAt'] as Object?)?.toString().trim() ?? '';
    if (name.isEmpty || data.isEmpty) return null;
    return {
      'name': name,
      'mimeType': mimeType,
      'data': data,
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

  String _resumeMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
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

  Future<void> _uploadResume() async {
    if (_uploadingResume) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
        withReadStream: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      final ext = (file.extension ?? '').toLowerCase();
      const allowed = {'pdf', 'doc', 'docx'};
      if (!allowed.contains(ext)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please choose a PDF, DOC, or DOCX file.'),
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

      const maxBytes = 5 * 1024 * 1024;
      if (bytes.length > maxBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resume must be 5MB or smaller.')),
        );
        return;
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final profile = _profileData();
      profile['resume'] = {
        'name': file.name,
        'mimeType': _resumeMimeType(file.name),
        'data': base64Encode(bytes),
        'updatedAt': now,
      };

      setState(() => _uploadingResume = true);
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
          ? 'Upload is too large for the server. Restart backend with the latest code or use a smaller file.'
          : 'Upload failed: $message';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendly)));
    } finally {
      if (mounted) setState(() => _uploadingResume = false);
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
    final skills = _skills();
    final education = _education();
    final experience = _experience();

    return Scaffold(
      // backgroundColor: uses theme
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
            const Text(
              'SkillMatch',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(initialTab: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Edit Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openEdit,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Profile Avatar
                  _profileAvatar(avatarUrl: _s('avatarUrl')),
                  const SizedBox(height: 12),

                  // Name and Title
                  Text(
                    fullName,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    headline.isEmpty ? 'Add a headline (Edit)' : headline,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        location.isEmpty ? 'Add location' : location,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Email
                  Row(
                    children: [
                      const Icon(
                        Icons.email,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        email.isEmpty ? '—' : email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Phone
                  Row(
                    children: [
                      const Icon(
                        Icons.phone,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        phone.isEmpty ? 'Add phone' : phone,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Portfolio
                  Row(
                    children: [
                      const Icon(
                        Icons.link,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          portfolio.isEmpty ? 'Add portfolio link' : portfolio,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Skills Section
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Skills',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skills.isEmpty
                        ? const [_SkillTag(skill: 'Add skills (Edit)')]
                        : skills.map((s) => _SkillTag(skill: s)).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Experience Section
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Experience',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  if (experience.isEmpty)
                    const Text(
                      'Add experience (Edit)',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
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
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Education',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  if (education.isEmpty)
                    const Text(
                      'Add education (Edit)',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    )
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
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resume',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              resume == null
                                  ? 'PDF, DOC, or DOCX (max 5MB)'
                                  : _resumeDateLabel(resume['updatedAt'] ?? ''),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
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
            const SizedBox(height: 100),
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDEEEFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        skill,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2563EB),
        ),
      ),
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
    text: (widget.initial['phone'] as String?) ?? '',
  );
  late final TextEditingController _portfolio = TextEditingController(
    text: (widget.initial['portfolioUrl'] as String?) ?? '',
  );
  late final TextEditingController _bio = TextEditingController(
    text: (widget.initial['bio'] as String?) ?? '',
  );
  late String _avatarUrl = (widget.initial['avatarUrl'] as String?) ?? '';
  late final TextEditingController _skills = TextEditingController(
    text: (() {
      final v = widget.initial['skills'];
      if (v is List) return v.map((e) => e.toString()).join(', ');
      return '';
    })(),
  );
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
        if (year.isEmpty && title.isEmpty && company.isEmpty && desc.isEmpty)
          continue;
        lines.add('$year | $title | $company | $desc'.trim());
      }
      return lines.join('\n');
    })(),
  );

  final _imagePicker = ImagePicker();
  bool _saving = false;

  String _mimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _pickAvatar() async {
    if (_saving) return;
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final mimeType = _mimeTypeFromPath(file.path);
      final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      setState(() {
        _avatarUrl = dataUri;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
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
    _skills.dispose();
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
          description.isEmpty)
        continue;
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
    setState(() => _saving = true);
    try {
      final user = await updateMyProfile({
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'headline': _headline.text.trim(),
        'location': _location.text.trim(),
        'phone': _phone.text.trim(),
        'portfolioUrl': _portfolio.text.trim(),
        'bio': _bio.text.trim(),
        'avatarUrl': _avatarUrl.trim(),
        'skills': _skills.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
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
    return Padding(
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
                const Text(
                  'Edit profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                        onPressed: _saving ? null : _pickAvatar,
                        icon: const Icon(Icons.upload),
                        label: const Text('Upload photo'),
                      ),
                      if (_avatarUrl.trim().isNotEmpty)
                        TextButton(
                          onPressed: _saving
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
            TextField(controller: _phone, decoration: _dec('Phone')),
            const SizedBox(height: 12),
            TextField(
              controller: _portfolio,
              decoration: _dec('Portfolio URL'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _skills,
              decoration: _dec('Skills (comma separated)'),
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
