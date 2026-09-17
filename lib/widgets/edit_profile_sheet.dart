import 'package:image_picker/image_picker.dart';
import '../config/cloudinary_config.dart';
import '../services/cloudinary_service.dart';
import 'dart:io' show File;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/profile_api.dart';
import '../services/session_store.dart';
import '../services/job_roles_data.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'widgets.dart';

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

class EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> initial;
  const EditProfileSheet({required this.initial});

  @override
  State<EditProfileSheet> createState() => EditProfileSheetState();
}

class EditProfileSheetState extends State<EditProfileSheet> {
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

  InputDecoration _dec(String hint) {
    final tokens = context.appColors;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: tokens.textFaint, fontSize: 14),
      filled: true,
      fillColor: tokens.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: tokens.cardBorderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: tokens.cardBorderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: tokens.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
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
                        icon: Icon(Icons.close, color: tokens.textSecondary),
                        tooltip: 'Cancel',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Edit profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: tokens.primary,
                            ),
                          )
                        : Text(
                            'Save',
                            style: TextStyle(
                              color: tokens.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _profileAvatar(
                    context,
                    avatarUrl: _avatarUrl,
                    size: 72,
                    radius: 12,
                  ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
              Text(
                'Skills',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              SkillsSelector(
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
class SkillsSelector extends StatefulWidget {
  final List<String> options;
  final List<String> initialSelected;
  final ValueChanged<List<String>> onChanged;

  const SkillsSelector({
    required this.options,
    required this.initialSelected,
    required this.onChanged,
  });

  @override
  State<SkillsSelector> createState() => SkillsSelectorState();
}

class SkillsSelectorState extends State<SkillsSelector> {
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
    final tokens = context.appColors;
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
                    label: Text(
                      s,
                      style: TextStyle(fontSize: 13, color: tokens.primary),
                    ),
                    onDeleted: () => _toggle(s),
                    backgroundColor: tokens.primarySoftBg,
                    side: BorderSide(color: tokens.cardBorderSoft),
                    labelStyle: TextStyle(color: tokens.primary),
                    deleteIconColor: tokens.primary,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _searchController,
          style: TextStyle(color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search or type your own skill',
            hintStyle: TextStyle(color: tokens.textFaint, fontSize: 14),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: tokens.textSecondary,
            ),
            filled: true,
            fillColor: tokens.surfaceMuted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: tokens.cardBorderSoft),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: tokens.cardBorderSoft),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: tokens.primary, width: 2),
            ),
          ),
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: _addCustom,
        ),
        if (trimmedQuery.isNotEmpty && !hasExactMatch) ...[
          const SizedBox(height: 8),
          ActionChip(
            avatar: Icon(Icons.add, size: 16, color: tokens.primary),
            label: Text(
              'Add "$trimmedQuery" as a skill',
              style: TextStyle(
                fontSize: 13,
                color: tokens.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => _addCustom(trimmedQuery),
            backgroundColor: tokens.cardBackground,
            side: BorderSide(color: tokens.primary),
          ),
        ],
        const SizedBox(height: 8),
        if (widget.options.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Loading skill list…',
              style: TextStyle(fontSize: 13, color: tokens.textSecondary),
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
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ]
                    : available
                          .map(
                            (s) => ActionChip(
                              avatar: Icon(
                                Icons.add,
                                size: 16,
                                color: tokens.textSecondary,
                              ),
                              label: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              onPressed: () => _toggle(s),
                              backgroundColor: tokens.cardBackground,
                              side: BorderSide(color: tokens.cardBorderSoft),
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
