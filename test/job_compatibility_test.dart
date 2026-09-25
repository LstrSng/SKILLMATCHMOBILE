import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/pages/job_detail_page.dart';
import 'package:skillmatch/services/prescriptive_engine.dart';
import 'package:skillmatch/models/training_pathway.dart';
import 'package:skillmatch/services/pathway_links_data.dart';
import 'package:skillmatch/services/competency.dart';
import 'package:skillmatch/theme/app_theme.dart';
import 'package:skillmatch/widgets/widgets.dart';

void main() {
  group('SkillCompatibilityMatrix Tests', () {
    testWidgets('renders overview and filters skills correctly', (
      tester,
    ) async {
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

    testWidgets('handles very long skill names without horizontal overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 320, // small screen width
              child: SingleChildScrollView(
                child: SkillCompatibilityMatrix(
                  matchedSkills: const [
                    'Aesthetic and Design Sensibilities Level 4',
                  ],
                  missingSkills: const [
                    'Agile Coaching and Organizational Change Level 4',
                  ],
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
    testWidgets(
      'JobCardSkeleton and JobDetailSkeleton render without exception',
      (tester) async {
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
      },
    );
  });

  group('RecommendationCard Tests', () {
    testWidgets('renders AI match recommendation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: RecommendationCard(
                recommendation:
                    'Skill gap detected in Docker, React. Recommended certification tracks available via TESDA CSS NC II or Docker Certified Associate.',
              ),
            ),
          ),
        ),
      );

      // Verify header and recommendation
      expect(find.text('Smart Match Recommendation'), findsOneWidget);
      expect(
        find.textContaining('Skill gap detected in Docker, React'),
        findsOneWidget,
      );

      // Verify bottom buttons are not present
      expect(find.text('TESDA Programs'), findsNothing);
      expect(find.text('All 50+ Pathways'), findsNothing);
    });

    testWidgets('renders nothing when recommendation is empty or placeholder', (
      tester,
    ) async {
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

      expect(find.text('Smart Match Recommendation'), findsNothing);
      expect(find.text('TESDA Programs'), findsNothing);
    });
  });

  group('SkillCompatibilityMatrix Learn Pathway Tests', () {
    testWidgets(
      'renders Learn button on missing skills and triggers callback',
      (tester) async {
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
      },
    );
  });

  group('Prescriptive Analytics Tests', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test(
      'role-aware skill selection prioritizes domain-matching missing skill',
      () {
        expect(
          selectPrimaryPrescriptionSkill([
            'PostgreSQL',
            'Docker',
            'TypeScript',
          ], jobTitle: 'Associate User Interface'),
          equals('TypeScript'),
        );
        expect(
          selectPrimaryPrescriptionSkill([
            'HTML',
            'Docker',
            'Figma',
          ], jobTitle: 'DevOps Engineer'),
          equals('Docker'),
        );
        expect(
          selectPrimaryPrescriptionSkill([
            'PostgreSQL',
            'Unit Tests',
            'CSS',
          ], jobTitle: 'QA Automation Engineer'),
          equals('Unit Tests'),
        );
      },
    );

    test('simulates the match gain of learning each missing skill', () async {
      final actions = await prescribeActions(
        jobTitle: 'Associate User Interface',
        requiredSkills: ['HTML', 'CSS', 'PostgreSQL', 'Docker', 'TypeScript'],
        user: {
          'skills': ['HTML', 'CSS'],
        },
      );
      expect(actions, hasLength(3));
      for (final a in actions) {
        expect(a.currentScore, 40);
        expect(a.newScore, 60);
        expect(a.matchGain, 20);
        expect(a.isLevelUp, isFalse);
      }
      // Role relevance ranks TypeScript first for a UI job.
      expect(actions.first.skill, 'TypeScript');
      expect(actions.first.roleRelevant, isTrue);
      expect(actions.first.certification, isNotNull);
      final priorities = actions.map((a) => a.priority).toList();
      expect(
        priorities,
        equals([...priorities]..sort((x, y) => y.compareTo(x))),
      );
    });

    test(
      'prescribes raising a skill that is below the required PSF level',
      () async {
        final actions = await prescribeActions(
          jobTitle: 'Business Analyst',
          requiredSkills: [
            'Business Needs Analysis Level 3',
            'Budgeting Level 2',
          ],
          user: {
            'skills': ['Business Needs Analysis', 'Budgeting'],
            'skillLevels': {'Business Needs Analysis': 2, 'Budgeting': 5},
          },
        );
        expect(actions, hasLength(1));
        final a = actions.single;
        expect(a.skill, 'Business Needs Analysis');
        expect(a.isLevelUp, isTrue);
        expect(a.levelChange, 'Level 2 → Level 3');
        expect(a.currentScore, 75); // (2/4 + 1) / 2
        expect(a.newScore, 100);
        final text = prescriptionText(score: 75, actions: actions);
        expect(
          text,
          contains('raise Business Needs Analysis from Level 2 to Level 3'),
        );
      },
    );

    test(
      'prefers skills with a free certification when impact is equal',
      () async {
        final actions = await prescribeActions(
          jobTitle: 'Marketing Associate',
          requiredSkills: ['Communication', 'Digital Marketing'],
          user: const {'skills': <String>[]},
        );
        expect(actions.first.skill, 'Digital Marketing');
        expect(actions.first.certification?.provider, contains('TESDA'));
        expect(actions.last.certification, isNull);
      },
    );

    test(
      'recommends professional certifications for advanced levels',
      () async {
        final pathways = await allTrainingPathways();
        final basic = bestCertificationFor(
          pathways,
          'Cloud Computing',
          RequiredLevel.parse('Cloud Computing Level 2'),
        );
        final advanced = bestCertificationFor(
          pathways,
          'Cloud Computing',
          RequiredLevel.parse('Cloud Computing Level 5'),
        );
        expect(basic?.cost, TrainingCost.free);
        expect(advanced?.cost, TrainingCost.paid);
      },
    );

    test(
      'prescription text names the best next step and its certification',
      () async {
        final actions = await prescribeActions(
          jobTitle: 'Associate User Interface',
          requiredSkills: ['HTML', 'CSS', 'PostgreSQL', 'Docker', 'TypeScript'],
          user: {
            'skills': ['HTML', 'CSS'],
          },
        );
        final text = prescriptionText(score: 40, actions: actions);
        expect(
          text,
          startsWith(
            'Skill gap detected (40%). Best next step: learn TypeScript',
          ),
        );
        expect(text, contains('raises your match to 60%'));
        expect(text, contains('Recommended: '));
        expect(
          prescriptionText(score: 100, actions: const []),
          contains('Ready to apply!'),
        );
      },
    );
  });

  group('CollapsibleJobDescription Tests', () {
    testWidgets('shows See more and expands/collapses long descriptions', (
      tester,
    ) async {
      final longDesc = List.generate(
        6,
        (i) =>
            'Line $i: Developing scalable Flutter mobile applications with rich user interfaces.',
      ).join('\n');

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CollapsibleJobDescription(description: longDesc),
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

    testWidgets('does not show See more for short descriptions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: CollapsibleJobDescription(
                description:
                    'Short job description that easily fits on one line.',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Job Description'), findsOneWidget);
      expect(
        find.text('Short job description that easily fits on one line.'),
        findsOneWidget,
      );
      expect(find.text('See more'), findsNothing);
      expect(find.text('Show less'), findsNothing);
    });
  });
}
