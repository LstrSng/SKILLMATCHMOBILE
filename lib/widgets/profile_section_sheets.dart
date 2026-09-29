import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/applicant_background.dart';
import '../services/employment_proof.dart';
import '../services/job_roles_data.dart';
import '../services/profile_api.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'background_fields.dart';
import 'edit_profile_sheet.dart';

/// Small sheets that edit and save one profile section at a time, so the
/// user doesn't have to open the full [EditProfileSheet] (and its skills
/// picker) just to change their experience or education. Each returns the
/// updated user on save, or null if dismissed.

Future<Map<String, dynamic>?> showYearsOfExperienceSheet(
  BuildContext context,
  Map<String, dynamic> user,
) {
  var years = readYearsOfExperience(user) ?? 0;
  return _showSectionSheet(
    context,
    title: 'Years of work experience',
    body: (setState) => ExperienceYearsStepper(
      value: years,
      onChanged: (v) => setState(() => years = v),
    ),
    save: () => updateMyProfile({'yearsOfExperience': years}),
  );
}

Future<Map<String, dynamic>?> showHighestEducationSheet(
  BuildContext context,
  Map<String, dynamic> user,
) {
  var level = readHighestEducation(user);
  return _showSectionSheet(
    context,
    title: 'Highest education',
    body: (setState) => EducationLevelPicker(
      value: level,
      onChanged: (v) => setState(() => level = v),
    ),
    canSave: () => level != null,
    save: () => updateMyProfile({'highestEducation': level}),
  );
}

Future<Map<String, dynamic>?> showSkillsSheet(
  BuildContext context,
  Map<String, dynamic> user,
) {
  var skills = [
    for (final s in (user['skills'] as List? ?? const []))
      if (s.toString().trim().isNotEmpty) s.toString(),
  ];
  var levels = readSkillLevels(user);
  final options = loadSkillOptions();
  return _showSectionSheet(
    context,
    title: 'Skills',
    body: (setState) => FutureBuilder<List<String>>(
      future: options,
      builder: (context, snap) => SkillsSelector(
        options: snap.data ?? const [],
        initialSelected: skills,
        initialLevels: levels,
        // Only add/remove refreshes the sheet (for the Save button);
        // dragging a level slider stays inside the selector.
        onChanged: (list) => setState(() => skills = list),
        onLevelsChanged: (map) => levels = map,
      ),
    ),
    canSave: () => skills.isNotEmpty,
    save: () => updateMyProfile({
      'skills': skills,
      'skillLevels': {
        for (final s in skills) s: levels[s] ?? kDefaultSkillLevel,
      },
    }),
  );
}

Future<Map<String, dynamic>?> showEducationSheet(
  BuildContext context,
  Map<String, dynamic> user,
) {
  final controller = TextEditingController(
    text: educationToText(user['education']),
  );
  var level = readHighestEducation(user);
  return _showSectionSheet(
    context,
    title: 'Education',
    body: (setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Highest education'),
        const SizedBox(height: 8),
        EducationLevelPicker(
          value: level,
          onChanged: (v) => setState(() => level = v),
        ),
        const SizedBox(height: 16),
        _Label('Schools'),
        const SizedBox(height: 8),
        _LinesField(
          controller: controller,
          hint: 'One per line: Degree | School | Years',
          example:
              'BS Information Technology | National University - Manila | 2020–2024',
        ),
      ],
    ),
    save: () => updateMyProfile({
      'education': parseEducationText(controller.text),
      'highestEducation': ?level,
    }),
    onDispose: controller.dispose,
  );
}

Future<Map<String, dynamic>?> _showSectionSheet(
  BuildContext context, {
  required String title,
  required Widget Function(StateSetter setState) body,
  required Future<Map<String, dynamic>> Function() save,
  bool Function()? canSave,
  VoidCallback? onDispose,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.appColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _SectionSheet(
      title: title,
      body: body,
      save: save,
      canSave: canSave,
      onDispose: onDispose,
    ),
  );
}

class _SectionSheet extends StatefulWidget {
  const _SectionSheet({
    required this.title,
    required this.body,
    required this.save,
    this.canSave,
    this.onDispose,
  });

  final String title;
  final Widget Function(StateSetter setState) body;
  final Future<Map<String, dynamic>> Function() save;
  final bool Function()? canSave;

  /// Runs once the sheet is gone, e.g. to dispose its text controllers.
  final VoidCallback? onDispose;

  @override
  State<_SectionSheet> createState() => _SectionSheetState();
}

class _SectionSheetState extends State<_SectionSheet> {
  bool _saving = false;

  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = await widget.save();
      if (mounted) Navigator.pop(context, user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final enabled = !_saving && (widget.canSave?.call() ?? true);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.cardBorderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            widget.body(setState),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: enabled ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.appColors.textPrimary,
      ),
    );
  }
}

class _LinesField extends StatelessWidget {
  const _LinesField({
    required this.controller,
    required this.hint,
    required this.example,
  });

  final TextEditingController controller;
  final String hint;
  final String example;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: 5,
          style: TextStyle(color: tokens.textPrimary, fontSize: 14),
          decoration: InputDecoration(
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
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'e.g. $example',
          style: TextStyle(fontSize: 11.5, color: tokens.textSecondary),
        ),
      ],
    );
  }
}

/// Add (index == null) or edit one job, including its Certificate of
/// Employment PDF. Returns the updated user on save/delete.
Future<Map<String, dynamic>?> showExperienceEntrySheet(
  BuildContext context,
  Map<String, dynamic> user, {
  int? index,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.appColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ExperienceEntrySheet(user: user, index: index),
  );
}

class _ExperienceEntrySheet extends StatefulWidget {
  const _ExperienceEntrySheet({required this.user, this.index});

  final Map<String, dynamic> user;
  final int? index;

  @override
  State<_ExperienceEntrySheet> createState() => _ExperienceEntrySheetState();
}

class _ExperienceEntrySheetState extends State<_ExperienceEntrySheet> {
  late final List<Map<String, dynamic>> _items = storedExperienceItems(
    widget.user,
  );
  late final Map<String, dynamic> _existing =
      widget.index != null && widget.index! < _items.length
      ? _items[widget.index!]
      : const {};

  String _field(String k) => (_existing[k] as Object?)?.toString() ?? '';

  late final _title = TextEditingController(text: _field('title'));
  late final _company = TextEditingController(text: _field('company'));
  late final _year = TextEditingController(text: _field('year'));
  late final _description = TextEditingController(text: _field('description'));

  /// The saved certificate, kept unless removed or replaced.
  late Map<String, dynamic>? _proof = _existing['proof'] is Map
      ? Map<String, dynamic>.from(_existing['proof'] as Map)
      : null;
  PlatformFile? _newFile;
  String? _titleError;
  String? _fileError;
  bool _saving = false;

  bool get _isEdit => _existing.isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _year.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || !mounted) return;
    setState(() {
      if ((file.extension ?? '').toLowerCase() != 'pdf') {
        _fileError = 'Choose a PDF file.';
      } else if (file.bytes == null) {
        _fileError = "Couldn't read that file. Try another.";
      } else if (file.size > kMaxEmploymentProofBytes) {
        _fileError = 'The PDF must be 10 MB or smaller.';
      } else {
        _newFile = file;
        _fileError = null;
      }
    });
  }

  Future<void> _persist(List<Map<String, dynamic>> items) async {
    setState(() => _saving = true);
    try {
      final user = await updateMyProfile({'experience': items});
      if (mounted) Navigator.pop(context, user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Enter your job title.');
      return;
    }
    setState(() => _saving = true);
    Map<String, dynamic>? proof = _proof;
    final file = _newFile;
    if (file != null) {
      try {
        proof = await uploadEmploymentProofPdf(
          fileName: file.name,
          bytes: file.bytes!,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        return;
      }
    }
    final item = {
      'year': _year.text.trim(),
      'title': title,
      'company': _company.text.trim(),
      'description': _description.text.trim(),
      'proof': proof,
    };
    final items = List.of(_items);
    if (_isEdit) {
      items[widget.index!] = item;
    } else {
      // Newest role first, matching how the profile lists them.
      items.insert(0, item);
    }
    await _persist(items);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this job?'),
        content: const Text(
          'This removes the job and its Certificate of Employment from your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _persist(List.of(_items)..removeAt(widget.index!));
  }

  InputDecoration _dec(String label, {String? hint, String? error}) {
    final tokens = context.appColors;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 14),
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

  Widget _buildCertificate() {
    final tokens = context.appColors;
    final name = _newFile?.name ?? (_proof?['name'] as String?);
    final Widget box;
    if (name == null) {
      box = OutlinedButton.icon(
        onPressed: _saving ? null : _pickFile,
        icon: const Icon(Icons.upload_file_rounded, size: 18),
        label: const Text('Choose PDF'),
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.primary,
          side: BorderSide(color: tokens.primary.withValues(alpha: 0.4)),
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      box = Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: tokens.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.cardBorderSoft),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              size: 20,
              color: AppColors.danger,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Remove file',
              icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _newFile = null;
                      _proof = null;
                    }),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Certificate of Employment (optional)'),
        const SizedBox(height: 8),
        box,
        const SizedBox(height: 6),
        Text(
          _fileError ?? 'PDF only, up to 10 MB.',
          style: TextStyle(
            fontSize: 11.5,
            color: _fileError != null ? AppColors.danger : tokens.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.cardBorderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit experience' : 'Add experience',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                if (_isEdit)
                  IconButton(
                    tooltip: 'Delete job',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    onPressed: _saving ? null : _delete,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: tokens.textPrimary),
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
              decoration: _dec(
                'Job title',
                hint: 'e.g. Junior Web Developer',
                error: _titleError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _company,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: tokens.textPrimary),
              decoration: _dec('Company', hint: 'e.g. Accenture Philippines'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _year,
              style: TextStyle(color: tokens.textPrimary),
              decoration: _dec('Years', hint: 'e.g. 2022 – 2024'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              style: TextStyle(color: tokens.textPrimary),
              decoration: _dec(
                'Description (optional)',
                hint: 'What you did in this role',
              ),
            ),
            const SizedBox(height: 16),
            _buildCertificate(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
