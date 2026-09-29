import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/applicant_background.dart';
import 'package:skillmatch/theme/app_colors.dart';

/// Single-choice chips for highest educational attainment.
class EducationLevelPicker extends StatelessWidget {
  const EducationLevelPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final level in kEducationLevels)
          Builder(
            builder: (context) {
              final selected = level == value;
              return Material(
                color: selected ? tokens.primary : tokens.cardBackground,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: selected ? tokens.primary : tokens.cardBorderSoft,
                  ),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(level);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Text(
                      level,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : tokens.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// A − / + stepper for years of work experience (0 to 40+).
class ExperienceYearsStepper extends StatelessWidget {
  const ExperienceYearsStepper({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    Widget button(IconData icon, String tooltip, int next) {
      final enabled = next >= 0 && next <= kMaxExperienceYears;
      return IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged(next);
              }
            : null,
        icon: Icon(icon, size: 20),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.cardBorderSoft),
      ),
      child: Row(
        children: [
          button(Icons.remove_rounded, 'Fewer years', value - 1),
          Expanded(
            child: Semantics(
              label: 'Years of experience',
              value: experienceLabel(value),
              child: Text(
                experienceLabel(value),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ),
          button(Icons.add_rounded, 'More years', value + 1),
        ],
      ),
    );
  }
}
