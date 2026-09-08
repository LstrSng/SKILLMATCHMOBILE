import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/skill_assessment.dart';
import 'package:skillmatch/services/skill_assessment_engine.dart';

void main() {
  group('MongoDB Assessment Model & Parser Tests', () {
    test('parses MongoDB assessment document and questions correctly', () {
      final sampleDoc = {
        '_id': '6a8bf10521ee7f220539d67a',
        'roleId': 'user-interface-ui-designer',
        'roleTitle': 'User Interface (UI) Designer',
        'title': 'User Interface (UI) Designer Competency Assessment',
        'track': 'UI/UX & Product Design',
        'description': 'PSF assessment for UI Designer',
        'passingScorePercentage': 70,
        'timeLimitMinutes': 25,
        'questions': [
          {
            'questionId': 'ui-q1',
            'prompt': 'When designing a data-dense dashboard, which typography technique best establishes hierarchy?',
            'options': [
              'Use 6 different font families',
              'Use a single versatile font family with systematic variations',
              'Set all text in uppercase bold',
              'Use italicized serif fonts',
            ],
            'correctAnswer': 'Use a single versatile font family with systematic variations',
            'explanation': 'A constrained scale creates strong scanning anchors.',
            'competency': 'Aesthetic and Design Sensibilities',
            'skillType': 'Functional Competency',
            'difficulty': 'Mid-Level',
            'points': 5,
            'timeLimitSeconds': 120,
          },
        ],
      };

      final category = AssessmentCategory.fromJson(sampleDoc);
      expect(category.id, '6a8bf10521ee7f220539d67a');
      expect(category.key, 'user-interface-ui-designer');
      expect(category.label, 'User Interface (UI) Designer');
      expect(category.track, 'UI/UX & Product Design');
      expect(category.passingScorePercentage, 70);
      expect(category.questions.length, 1);

      final q = category.questions.first;
      expect(q.id, 'ui-q1');
      expect(q.correctIndex, 1);
      expect(q.correctAnswer, 'Use a single versatile font family with systematic variations');
      expect(q.difficulty, 2);
      expect(q.difficultyLabel, 'Mid-Level');
      expect(q.explanation, 'A constrained scale creates strong scanning anchors.');
    });

    test('AssessmentEngine executes quiz and computes pass/fail and percentage', () {
      final questions = [
        const AssessmentQuestion(
          id: 'q1',
          text: 'Question 1',
          options: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
          correctIndex: 0,
          difficulty: 2,
        ),
        const AssessmentQuestion(
          id: 'q2',
          text: 'Question 2',
          options: ['A', 'B', 'C', 'D'],
          correctAnswer: 'B',
          correctIndex: 1,
          difficulty: 2,
        ),
      ];

      final category = AssessmentCategory(
        key: 'sample-role',
        label: 'Sample Role',
        description: 'Sample description',
        passingScorePercentage: 50,
        questions: questions,
      );

      final engine = AssessmentEngine(category, sessionLength: 2);
      expect(engine.isComplete, isFalse);

      final q1 = engine.nextQuestion()!;
      expect(q1.source.id, 'q1');
      engine.submitAnswer(0); // correct

      final q2 = engine.nextQuestion()!;
      expect(q2.source.id, 'q2');
      engine.submitAnswer(0); // wrong (expected 1)

      expect(engine.isComplete, isTrue);
      final result = engine.buildResult();

      expect(result.correctCount, 1);
      expect(result.totalCount, 2);
      expect(result.scorePercentage, 50);
      expect(result.passed, isTrue);
      expect(result.level, 'Intermediate');
      expect(engine.recordedAnswers.length, 2);
      expect(engine.recordedAnswers[0].isCorrect, isTrue);
      expect(engine.recordedAnswers[1].isCorrect, isFalse);
    });

    test('AssessmentQuestion defaults to 30 seconds time limit', () {
      const q = AssessmentQuestion(
        id: 'q_default',
        text: 'Default timeout test',
        options: ['A', 'B'],
        correctIndex: 0,
        difficulty: 1,
      );
      expect(q.timeLimitSeconds, 30);
    });

    test('AssessmentResult formats date and time strings accurately', () {
      final res = AssessmentResult(
        categoryKey: 'devops',
        roleTitle: 'DevOps Engineer',
        level: 'Job-ready',
        ability: 3.5,
        correctCount: 9,
        totalCount: 10,
        scorePercentage: 90,
        passed: true,
        takenAt: DateTime(2026, 9, 8, 14, 30),
      );

      expect(res.formattedDateOnly, 'Sep 8, 2026');
      expect(res.formattedDate, contains('Sep 8, 2026'));
      expect(res.formattedDate, contains('2:30 PM'));
    });

    test('AssessmentEngine handles timeout (-1) as wrong answer', () {
      final category = AssessmentCategory(
        key: 'timeout-role',
        label: 'Timeout Role',
        description: 'Test timeout',
        passingScorePercentage: 70,
        questions: const [
          AssessmentQuestion(
            id: 'tq1',
            text: 'Question 1',
            options: ['Option A', 'Option B'],
            correctIndex: 0,
            difficulty: 1,
          ),
        ],
      );

      final engine = AssessmentEngine(category, sessionLength: 1);
      final q = engine.nextQuestion();
      expect(q, isNotNull);

      // Simulating question timer expiration:
      final isCorrect = engine.submitAnswer(-1);
      expect(isCorrect, isFalse);
      expect(engine.isComplete, isTrue);
      expect(engine.correctCount, 0);

      final recorded = engine.recordedAnswers.first;
      expect(recorded.selectedIndex, -1);
      expect(recorded.isCorrect, isFalse);
    });

    test('mergeAssessmentResult stores both skillAssessments map and assessmentRecords history', () {
      final initialProfile = <String, dynamic>{
        'headline': 'Software Engineer',
      };

      final result1 = AssessmentResult(
        categoryKey: 'frontend',
        roleTitle: 'Frontend Engineer',
        level: 'Advanced',
        ability: 3.0,
        correctCount: 8,
        totalCount: 10,
        scorePercentage: 80,
        passed: true,
        takenAt: DateTime(2026, 9, 8, 10, 0),
      );

      final updatedProfile1 = mergeAssessmentResult(initialProfile, result1);
      expect(updatedProfile1['headline'], 'Software Engineer');
      expect(updatedProfile1['skillAssessments']['frontend']['scorePercentage'], 80);

      final history1 = readAssessmentHistory(updatedProfile1);
      expect(history1.length, 1);
      expect(history1.first.categoryKey, 'frontend');
      expect(history1.first.scorePercentage, 80);

      // Submit second assessment
      final result2 = AssessmentResult(
        categoryKey: 'backend',
        roleTitle: 'Backend Engineer',
        level: 'Job-ready',
        ability: 3.8,
        correctCount: 10,
        totalCount: 10,
        scorePercentage: 100,
        passed: true,
        takenAt: DateTime(2026, 9, 8, 12, 0),
      );

      final updatedProfile2 = mergeAssessmentResult(updatedProfile1, result2);
      final history2 = readAssessmentHistory(updatedProfile2);
      expect(history2.length, 2);
      // Newest should be first (result2 taken at 12:00 vs result1 at 10:00)
      expect(history2.first.categoryKey, 'backend');
      expect(history2.first.scorePercentage, 100);
      expect(history2[1].categoryKey, 'frontend');
      expect(history2[1].scorePercentage, 80);
    });

    test('parses string-typed numerical fields without throwing type cast error', () {
      final rawResultWithStringNumbers = {
        'level': 'Job-ready',
        'ability': '3.20',
        'correctCount': '8',
        'totalCount': '10',
        'scorePercentage': '80',
        'passingScorePercentage': '70',
        'passed': 'true',
        'takenAt': '2026-09-08T15:30:00.000Z',
      };

      final parsed = AssessmentResult.fromJson('qa-tester', rawResultWithStringNumbers);
      expect(parsed, isNotNull);
      expect(parsed!.ability, 3.20);
      expect(parsed.correctCount, 8);
      expect(parsed.totalCount, 10);
      expect(parsed.scorePercentage, 80);
      expect(parsed.passed, isTrue);

      final rawQuestionWithStringNumbers = {
        'questionId': 'q_str',
        'prompt': 'Test prompt',
        'options': ['A', 'B'],
        'correctIndex': '1',
        'points': '10',
        'timeLimitSeconds': '30',
        'difficulty': 'Mid-Level',
      };

      final q = AssessmentQuestion.fromJson(rawQuestionWithStringNumbers);
      expect(q.correctIndex, 1);
      expect(q.points, 10);
      expect(q.timeLimitSeconds, 30);
    });
  });
}
