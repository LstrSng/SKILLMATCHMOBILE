import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/services/skill_assessment_bank.dart';
import 'package:skillmatch/services/skill_assessment_engine.dart';

void main() {
  test('every category has 4 easy, 4 medium, and 4 hard questions', () {
    for (final category in kAssessmentCategories) {
      final byTier = <int, int>{};
      for (final q in category.questions) {
        byTier[q.difficulty] = (byTier[q.difficulty] ?? 0) + 1;
      }
      expect(byTier[1], 4, reason: '${category.key} easy count');
      expect(byTier[2], 4, reason: '${category.key} medium count');
      expect(byTier[3], 4, reason: '${category.key} hard count');
    }
  });

  test(
    'presented question options are shuffled without losing the correct answer',
    () {
      final category = kAssessmentCategories.first;
      final engine = AssessmentEngine(category);
      final question = engine.nextQuestion()!;
      final correctText = question.source.options[question.source.correctIndex];
      expect(question.options[question.correctIndex], correctText);
      expect(question.options.toSet(), question.source.options.toSet());
    },
  );

  test(
    'a session asks exactly kAssessmentSessionLength questions with no repeats',
    () {
      final category = kAssessmentCategories.first;
      final engine = AssessmentEngine(category);
      final seenIds = <String>{};

      var question = engine.nextQuestion();
      var rounds = 0;
      while (question != null && rounds < 50) {
        expect(seenIds.contains(question.source.id), isFalse);
        seenIds.add(question.source.id);
        engine.submitAnswer(question.correctIndex); // always correct
        rounds += 1;
        question = engine.isComplete ? null : engine.nextQuestion();
      }

      expect(engine.askedCount, kAssessmentSessionLength);
      expect(engine.isComplete, isTrue);
    },
  );

  test('answering everything correctly lands at the top level', () {
    final category = kAssessmentCategories.first;
    final engine = AssessmentEngine(category);
    var question = engine.nextQuestion();
    while (question != null) {
      engine.submitAnswer(question.correctIndex);
      question = engine.isComplete ? null : engine.nextQuestion();
    }
    final result = engine.buildResult();
    expect(result.correctCount, kAssessmentSessionLength);
    expect(result.level, 'Job-ready');
  });

  test('answering everything incorrectly lands at the bottom level', () {
    final category = kAssessmentCategories.first;
    final engine = AssessmentEngine(category);
    var question = engine.nextQuestion();
    while (question != null) {
      final wrongIndex = (question.correctIndex + 1) % question.options.length;
      engine.submitAnswer(wrongIndex);
      question = engine.isComplete ? null : engine.nextQuestion();
    }
    final result = engine.buildResult();
    expect(result.correctCount, 0);
    expect(result.level, 'Beginner');
  });

  test('merging a result into an existing profile preserves other keys', () {
    final category = kAssessmentCategories.first;
    final engine = AssessmentEngine(category);
    var question = engine.nextQuestion();
    while (question != null) {
      engine.submitAnswer(question.correctIndex);
      question = engine.isComplete ? null : engine.nextQuestion();
    }
    final result = engine.buildResult();

    final existingProfile = <String, dynamic>{
      'resume': {'name': 'resume.pdf'},
    };
    final merged = mergeAssessmentResult(existingProfile, result);

    expect(merged['resume'], existingProfile['resume']);
    final saved = readAssessmentResults(merged);
    expect(saved[category.key]?.level, result.level);
  });
}
