import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'package:skillmatch/theme/app_theme.dart';
import 'package:skillmatch/widgets/widgets.dart';

void main() {
  group('AppCard Tests', () {
    testWidgets('renders child and responds to tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: AppCard(
              onTap: () => tapped = true,
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      await tester.tap(find.text('Card Content'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('renders all AppCardVariant types without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: Column(
              children: [
                AppCard(variant: AppCardVariant.elevated, child: Text('Elevated')),
                AppCard(variant: AppCardVariant.outlined, child: Text('Outlined')),
                AppCard(variant: AppCardVariant.filled, child: Text('Filled')),
                AppCard(variant: AppCardVariant.glass, child: Text('Glass')),
                AppCard(variant: AppCardVariant.gradient, child: Text('Gradient')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Elevated'), findsOneWidget);
      expect(find.text('Outlined'), findsOneWidget);
      expect(find.text('Filled'), findsOneWidget);
      expect(find.text('Glass'), findsOneWidget);
      expect(find.text('Gradient'), findsOneWidget);
    });
  });

  group('MatchScoreBadge Tests', () {
    testWidgets('renders pill variant with percentage and label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: MatchScoreBadge(
              score: 92,
              variant: MatchScoreBadgeVariant.pill,
              animate: false,
            ),
          ),
        ),
      );

      expect(find.text('92%'), findsOneWidget);
      expect(find.text('Match'), findsOneWidget);
    });

    testWidgets('renders circular and hero variants', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: Column(
              children: [
                MatchScoreBadge(
                  score: 85,
                  variant: MatchScoreBadgeVariant.circular,
                  animate: false,
                ),
                MatchScoreBadge(
                  score: 65,
                  variant: MatchScoreBadgeVariant.hero,
                  animate: false,
                ),
                MatchScoreBadge(
                  score: 30,
                  variant: MatchScoreBadgeVariant.compact,
                  animate: false,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('85%'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
    });

    test('Match score tier colors resolve correctly', () {
      expect(AppColors.matchColor(90), equals(AppColors.badgeHighMatch));
      expect(AppColors.matchColor(70), equals(AppColors.badgeMedMatch));
      expect(AppColors.matchColor(50), equals(AppColors.badgeLowMatch));
      expect(AppColors.matchColor(20), equals(AppColors.badgeGapMatch));

      expect(AppColors.matchColor(90, isDark: true), equals(AppColors.badgeHighMatchDark));
      expect(AppColors.matchColor(70, isDark: true), equals(AppColors.badgeMedMatchDark));
      expect(AppColors.matchColor(50, isDark: true), equals(AppColors.badgeLowMatchDark));
      expect(AppColors.matchColor(20, isDark: true), equals(AppColors.badgeGapMatchDark));
    });
  });

  group('SkillChip Tests', () {
    testWidgets('renders matched skill chip with icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SkillChip(
              label: 'Flutter',
              status: SkillChipStatus.matched,
            ),
          ),
        ),
      );

      expect(find.text('Flutter'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('renders missing skill chip with alert mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SkillChip(
              label: 'Docker',
              status: SkillChipStatus.missing,
              isMissingAlert: true,
            ),
          ),
        ),
      );

      expect(find.text('Docker'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    });

    testWidgets('renders verified skill chip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SkillChip(
              label: 'Dart',
              status: SkillChipStatus.verified,
            ),
          ),
        ),
      );

      expect(find.text('Dart'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('selectable chip toggles on tap', (tester) async {
      var selected = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              theme: buildLightTheme(),
              home: Scaffold(
                body: SkillChip(
                  label: 'Python',
                  status: SkillChipStatus.selectable,
                  selected: selected,
                  onSelected: (val) {
                    setState(() => selected = val);
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Python'), findsOneWidget);
      await tester.tap(find.text('Python'));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
    });

    testWidgets('chip with onDeleted triggers callback', (tester) async {
      var deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: SkillChip(
              label: 'React',
              onDeleted: () => deleted = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });
  });
}
