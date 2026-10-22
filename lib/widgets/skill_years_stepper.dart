import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/competency.dart';
import 'package:skillmatch/theme/app_colors.dart';

/// − / + stepper for years of experience with one skill. [years] is null
/// until the user sets it (older profiles only have a manual rating).
class SkillYearsStepper extends StatelessWidget {
  const SkillYearsStepper({
    super.key,
    required this.skill,
    required this.years,
    required this.onChanged,
  });

  final String skill;
  final int? years;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final value = years;

    Widget button(IconData icon, String tip, int next) {
      final enabled = next >= 0 && next <= kMaxSkillYears;
      return IconButton.filledTonal(
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 20),
        onPressed: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged(next);
              }
            : null,
      );
    }

    return Row(
      children: [
        button(Icons.remove_rounded, 'Fewer years of $skill', (value ?? 1) - 1),
        Expanded(
          child: Semantics(
            label: 'Years of experience with $skill',
            child: Text(
              value == null ? 'Set years' : skillYearsLabel(value),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: value == null ? tokens.textFaint : tokens.textPrimary,
              ),
            ),
          ),
        ),
        button(Icons.add_rounded, 'More years of $skill', (value ?? -1) + 1),
      ],
    );
  }
}
