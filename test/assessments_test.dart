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
  });
}
