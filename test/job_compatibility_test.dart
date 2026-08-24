import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/pages/job_detail_page.dart';
import 'package:skillmatch/theme/app_theme.dart';
import 'package:skillmatch/widgets/widgets.dart';

void main() {
  group('SkillCompatibilityMatrix Tests', () {
    testWidgets('renders overview and filters skills correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SkillCompatibilityMatrix(
                matchedSkills: ['Flutter', 'Dart'],
                missingSkills: ['Docker'],
                matchScore: 67,
              ),
            ),
          ),
        ),
      );

      // Verify overview stats
      expect(find.text('Skill Compatibility Matrix'), findsOneWidget);
      expect(find.text('2 Matched'), findsOneWidget);
      expect(find.text('1 Missing Gaps'), findsOneWidget);
      expect(find.text('3 Required'), findsOneWidget);

      // Verify all skills initially displayed
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
      expect(find.text('Docker'), findsOneWidget);

      // Filter by Matched
      await tester.tap(find.text('Matched (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
      expect(find.text('Docker'), findsNothing);

      // Filter by Missing
      await tester.tap(find.text('Missing (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Flutter'), findsNothing);
      expect(find.text('Dart'), findsNothing);
      expect(find.text('Docker'), findsOneWidget);
      expect(find.text('Skill Gap'), findsOneWidget);
    });

    testWidgets('handles very long skill names without horizontal overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 320, // small screen width
              child: SingleChildScrollView(
                child: SkillCompatibilityMatrix(
                  matchedSkills: const ['Aesthetic and Design Sensibilities Level 4'],
                  missingSkills: const ['Agile Coaching and Organizational Change Level 4'],
                  matchScore: 50,
                  onLearnSkill: (_) {},
                  onTakeQuiz: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Verify matrix and chips render properly with zero overflow
      expect(find.text('Skill Compatibility Matrix'), findsOneWidget);
      expect(find.byType(SkillChip), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('Shimmer Skeletons Tests', () {
    testWidgets('JobCardSkeleton and JobDetailSkeleton render without exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: Column(
              children: [
                JobCardSkeleton(),
                Expanded(child: JobDetailSkeleton()),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(JobCardSkeleton), findsOneWidget);
      expect(find.byType(JobDetailSkeleton), findsOneWidget);
    });
  });
}
