import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:skillmatch/theme/app_colors.dart';

/// Asks which skills the user gained from completing [subject] (a pathway
/// or certification). [suggestions] (e.g. the skill gaps it covers) show
/// as chips to pick from, and other skills can be typed in. Returns the
/// picked skills (at least one), or null if dismissed.
Future<List<String>?> showSkillPickSheet(
  BuildContext context, {
  required String subject,
  List<String> suggestions = const [],
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.appColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SkillPickSheet(subject: subject, suggestions: suggestions),
  );
}

class _SkillPickSheet extends StatefulWidget {
  const _SkillPickSheet({required this.subject, required this.suggestions});

  final String subject;
  final List<String> suggestions;

  @override
  State<_SkillPickSheet> createState() => _SkillPickSheetState();
}

class _SkillPickSheetState extends State<_SkillPickSheet> {
  final _other = TextEditingController();

  /// Chips shown: the suggestions plus skills the user typed in.
  late final List<String> _options = [...widget.suggestions];

  /// Picked skills, in the order shown. A lone suggestion starts picked.
  late final Set<String> _picked = {
    if (widget.suggestions.length == 1) widget.suggestions.single,
  };
  String? _error;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  void _toggle(String skill) {
    HapticFeedback.selectionClick();
    setState(() {
      _picked.contains(skill) ? _picked.remove(skill) : _picked.add(skill);
      _error = null;
    });
  }

  void _addOther() {
    final skill = _other.text.trim();
    if (skill.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      final existing = _options
          .where((o) => o.toLowerCase() == skill.toLowerCase())
          .firstOrNull;
      if (existing == null) _options.add(skill);
      _picked.add(existing ?? skill);
      _other.clear();
      _error = null;
    });
  }

  void _continue() {
    // A typed skill that wasn't added yet still counts.
    _addOther();
    if (_picked.isEmpty) {
      setState(() => _error = 'Pick or add at least one skill.');
      return;
    }
    Navigator.of(context).pop([
      for (final o in _options)
        if (_picked.contains(o)) o,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
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
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.primarySoftBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology_rounded, color: tokens.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Which skills did you gain?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'From "${widget.subject}". Pick all that apply; '
              "they'll be added to your profile skills.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tokens.textSecondary),
            ),
            if (_options.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _options)
                    FilterChip(
                      label: Text(s),
                      selected: _picked.contains(s),
                      onSelected: (_) => _toggle(s),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _other,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addOther(),
              decoration: InputDecoration(
                labelText: _options.isEmpty ? 'Skill' : 'Add another skill',
                errorText: _error,
                suffixIcon: IconButton(
                  tooltip: 'Add skill',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _addOther,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _continue,
                    child: Text(
                      _picked.length > 1
                          ? 'Continue (${_picked.length})'
                          : 'Continue',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
