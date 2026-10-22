import 'package:flutter/material.dart';

import 'package:skillmatch/theme/app_colors.dart';

/// Ten bars showing a 1–10 skill level, filled up to [level]. The level
/// starts from the years of experience entered for the skill; when
/// [onChanged] is set the bars can also be tapped or dragged to adjust it.
class SkillLevelMeter extends StatelessWidget {
  const SkillLevelMeter({
    super.key,
    required this.level,
    required this.color,
    this.showEndLabels = true,
    this.onChanged,
  });

  final int level;
  final Color color;
  final bool showEndLabels;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Semantics(
      label: 'Skill level',
      value: '$level out of 10',
      increasedValue: '${(level + 1).clamp(1, 10)} out of 10',
      decreasedValue: '${(level - 1).clamp(1, 10)} out of 10',
      onIncrease: onChanged == null
          ? null
          : () => onChanged!((level + 1).clamp(1, 10)),
      onDecrease: onChanged == null
          ? null
          : () => onChanged!((level - 1).clamp(1, 10)),
      excludeSemantics: true,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              void pick(double dx) {
                final i = (dx / constraints.maxWidth * 10).floor() + 1;
                onChanged?.call(i.clamp(1, 10));
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: onChanged == null
                    ? null
                    : (d) => pick(d.localPosition.dx),
                onHorizontalDragUpdate: onChanged == null
                    ? null
                    : (d) => pick(d.localPosition.dx),
                child: SizedBox(
                  height: 28,
                  child: Row(
                    children: List.generate(10, (i) {
                      final filled = i < level;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: EdgeInsets.only(right: i == 9 ? 0 : 4),
                          height: filled ? 28 : 20,
                          decoration: BoxDecoration(
                            color: filled ? color : tokens.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                            border: filled
                                ? null
                                : Border.all(color: tokens.cardBorderSoft),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
          if (showEndLabels) ...[
            const SizedBox(height: 6),
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
          ],
        ],
      ),
    );
  }
}
