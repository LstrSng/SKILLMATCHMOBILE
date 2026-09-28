import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/competency.dart';
import 'package:skillmatch/theme/app_colors.dart';

/// Asks the user how good they now are at [skill] on the 1–10 scale,
/// starting at [initialLevel]. Returns the picked level, or null if the
/// sheet was dismissed. [required] (the job's level) adds a hint about
/// the rating needed to qualify.
Future<int?> showSkillLevelSheet(
  BuildContext context, {
  required String skill,
  required int initialLevel,
  RequiredLevel? required,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.appColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SkillLevelSheet(
      skill: skill,
      initialLevel: initialLevel.clamp(1, 10),
      required: required,
    ),
  );
}

class _SkillLevelSheet extends StatefulWidget {
  const _SkillLevelSheet({
    required this.skill,
    required this.initialLevel,
    required this.required,
  });

  final String skill;
  final int initialLevel;
  final RequiredLevel? required;

  @override
  State<_SkillLevelSheet> createState() => _SkillLevelSheetState();
}

class _SkillLevelSheetState extends State<_SkillLevelSheet> {
  late int _level = widget.initialLevel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final req = widget.required;
    final scaled =
        req?.labelForRating(_level) ?? datasetLevelLabel(widget.skill, _level);
    final label = scaled == null
        ? skillLevelLabel(_level)
        : '${skillLevelLabel(_level)} ($scaled)';
    final meets = req == null || _level >= req.minRating;

    return Padding(
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
            'What is your level in ${widget.skill} now?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This skill will be added to your profile at the level you pick.',
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                '$_level/10',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: tokens.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _level.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$_level',
            activeColor: tokens.primary,
            onChanged: (v) {
              final next = v.round();
              if (next == _level) return;
              HapticFeedback.selectionClick();
              setState(() => _level = next);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Beginner',
                style: TextStyle(fontSize: 11, color: tokens.textFaint),
              ),
              Text(
                'Expert',
                style: TextStyle(fontSize: 11, color: tokens.textFaint),
              ),
            ],
          ),
          if (req != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  meets ? Icons.check_circle_rounded : Icons.info_rounded,
                  size: 16,
                  color: meets ? tokens.success : tokens.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    meets
                        ? 'Meets the required ${req.label} for this job.'
                        : 'This job needs ${req.label} (at least ${req.minRating}/10).',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: tokens.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
                  onPressed: () => Navigator.of(context).pop(_level),
                  child: const Text('Save to skills'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
