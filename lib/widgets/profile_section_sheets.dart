import 'package:flutter/material.dart';

import '../services/applicant_background.dart';
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

Future<Map<String, dynamic>?> showExperienceSheet(
  BuildContext context,
  Map<String, dynamic> user,
) {
  final controller = TextEditingController(
    text: experienceToText(user['experience']),
  );
  return _showSectionSheet(
    context,
    title: 'Experience',
    body: (_) => _LinesField(
      controller: controller,
      hint: 'One per line: Years | Title | Company | Description',
      example: '2023–2024 | Junior Developer | Acme Inc. | Built web apps',
    ),
    save: () => updateMyProfile({
      'experience': keepExperienceProofs(
        user['experience'],
        parseExperienceText(controller.text),
      ),
    }),
    onDispose: controller.dispose,
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
