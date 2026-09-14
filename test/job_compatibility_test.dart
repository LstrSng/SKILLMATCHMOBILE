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

  group('RecommendationCard Tests', () {
    testWidgets('renders AI match recommendation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: RecommendationCard(
                recommendation: 'Skill gap detected in Docker, React. Recommended certification tracks available via TESDA CSS NC II or Docker Certified Associate.',
              ),
            ),
          ),
        ),
      );

      // Verify header and recommendation
      expect(find.text('AI Match Recommendation'), findsOneWidget);
      expect(find.textContaining('Skill gap detected in Docker, React'), findsOneWidget);

      // Verify bottom buttons are not present
      expect(find.text('TESDA Programs'), findsNothing);
      expect(find.text('All 50+ Pathways'), findsNothing);
    });

    testWidgets('renders nothing when recommendation is empty or placeholder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: RecommendationCard(
              recommendation: 'No recommendation available.',
            ),
          ),
        ),
      );

      expect(find.text('AI Match Recommendation'), findsNothing);
      expect(find.text('TESDA Programs'), findsNothing);
    });
  });

  group('SkillCompatibilityMatrix Learn Pathway Tests', () {
    testWidgets('renders Learn button on missing skills and triggers callback', (tester) async {
      String? learnedSkill;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SkillCompatibilityMatrix(
                matchedSkills: const ['Flutter'],
                missingSkills: const ['Docker'],
                matchScore: 50,
                onLearnSkill: (skill) {
                  learnedSkill = skill;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Learn'), findsOneWidget);
      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();

      expect(learnedSkill, equals('Docker'));
    });
  });

  group('Skill Prescription Tests', () {
    test('resolveSkillPrescription prescribes TypeScript certification and pathway', () {
      final tsRx = resolveSkillPrescription('TypeScript');
      expect(tsRx.skill, equals('TypeScript'));
      expect(tsRx.tesdaProgram, equals('TESDA Web Development NC III'));
      expect(tsRx.globalCert, contains('TypeScript'));
      expect(tsRx.providerSummary, contains('Microsoft'));
      expect(tsRx.searchKeyword, equals('TypeScript'));

      final tsAbbrRx = resolveSkillPrescription('TS');
      expect(tsAbbrRx.searchKeyword, equals('TypeScript'));
    });

    test('avoids false positive substring collisions for short abbreviations', () {
      // 'Unit Tests' should NOT match 'ts' (TypeScript), it should match 'test' (QA)
      final testsRx = resolveSkillPrescription('Unit Tests');
      expect(testsRx.searchKeyword, equals('QA'));
      expect(testsRx.globalCert, contains('ISTQB'));

      // 'Email Support' should NOT match 'ai' (Data/AI), it should match 'support' (Support)
      final supportRx = resolveSkillPrescription('Email Support');
      expect(supportRx.searchKeyword, equals('Support'));
      expect(supportRx.tesdaProgram, contains('Computer Systems Servicing'));

      // 'Recruiting' should NOT match 'ui' (UI/Design)
      final recruitRx = resolveSkillPrescription('Recruiting');
      expect(recruitRx.searchKeyword, isNot(equals('Design')));
    });

    test('role-aware skill selection prioritizes domain-matching missing skill', () {
      // For "Associate User Interface" with ['PostgreSQL', 'Docker', 'TypeScript'],
      // it should select 'TypeScript' because it aligns with UI/frontend, not PostgreSQL.
      final selectedUi = selectPrimaryPrescriptionSkill(
        ['PostgreSQL', 'Docker', 'TypeScript'],
        jobTitle: 'Associate User Interface',
      );
      expect(selectedUi, equals('TypeScript'));

      // For "DevOps Engineer" with ['HTML', 'Docker', 'Figma'], it should select 'Docker'.
      final selectedDevops = selectPrimaryPrescriptionSkill(
        ['HTML', 'Docker', 'Figma'],
        jobTitle: 'DevOps Engineer',
      );
      expect(selectedDevops, equals('Docker'));

      // For "QA Automation Engineer" with ['PostgreSQL', 'Unit Tests', 'CSS'], it should select 'Unit Tests'.
      final selectedQa = selectPrimaryPrescriptionSkill(
        ['PostgreSQL', 'Unit Tests', 'CSS'],
        jobTitle: 'QA Automation Engineer',
      );
      expect(selectedQa, equals('Unit Tests'));
    });

    test('buildJobRecommendation produces role-aware prescription text', () {
      final rec = buildJobRecommendation(
        0,
        ['PostgreSQL', 'Docker', 'TypeScript'],
        jobTitle: 'Associate User Interface',
      );

      // Verify that the recommendation explicitly mentions the role and prioritizes TypeScript
      expect(rec, contains('Associate User Interface role'));
      expect(rec, contains('prioritize TypeScript'));
      expect(rec, contains('TESDA Web Development NC III'));
      expect(rec, isNot(contains('Oracle Database')));
    });
  });

  group('CollapsibleJobDescription Tests', () {
    testWidgets('shows See more and expands/collapses long descriptions', (tester) async {
      final longDesc = List.generate(
        6,
        (i) => 'Line $i: Developing scalable Flutter mobile applications with rich user interfaces.',
      ).join('\n');

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CollapsibleJobDescription(
                description: longDesc,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Job Description'), findsOneWidget);
      expect(find.text('See more'), findsOneWidget);

      // Tap See more
      await tester.tap(find.text('See more'));
      await tester.pumpAndSettle();

      expect(find.text('Show less'), findsOneWidget);
      expect(find.text('See more'), findsNothing);

      // Scroll to Show less and tap
      await tester.ensureVisible(find.text('Show less'));
      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();

      expect(find.text('See more'), findsOneWidget);
      expect(find.text('Show less'), findsNothing);
    });

    testWidgets('does not show See more for short descriptions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: CollapsibleJobDescription(
                description: 'Short job description that easily fits on one line.',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Job Description'), findsOneWidget);
      expect(find.text('Short job description that easily fits on one line.'), findsOneWidget);
      expect(find.text('See more'), findsNothing);
      expect(find.text('Show less'), findsNothing);
    });
  });
}
