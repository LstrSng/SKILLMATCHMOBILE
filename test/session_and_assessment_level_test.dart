import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillmatch/models/skill_assessment.dart';
import 'package:skillmatch/services/navigation_service.dart';
import 'package:skillmatch/services/notification_store.dart';
import 'package:skillmatch/services/session_store.dart';
import 'package:skillmatch/services/skill_assessment_engine.dart';

AssessmentResult _runQuiz(List<bool> answers) {
  final category = AssessmentCategory(
    key: 'role',
    label: 'Role',
    description: '',
    questions: [
      for (var i = 0; i < answers.length; i++)
        AssessmentQuestion(
          id: 'q$i',
          text: 'Question $i',
          options: const ['A', 'B'],
          correctIndex: 0,
          difficulty: 2,
        ),
    ],
  );
  final engine = AssessmentEngine(category, sessionLength: answers.length);
  for (final correct in answers) {
    final q = engine.nextQuestion()!;
    engine.submitAnswer(correct ? q.correctIndex : 1 - q.correctIndex);
  }
  return engine.buildResult();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('signing out resets the tab, unread badge and per-user key', () async {
    SharedPreferences.setMockInitialValues({});
    await SessionStore.save(token: 't', user: {'_id': 'user-1'});
    expect(SessionStore.userKey, 'user-1');
    AppNavigation.switchTab(AppTab.profile);
    NotificationStore.unreadCountNotifier.value = 3;

    await SessionStore.clear();

    expect(SessionStore.userKey, 'guest');
    expect(AppNavigation.activeTab, AppTab.dashboard);
    expect(NotificationStore.unreadCountNotifier.value, 0);
  });

  // The server replays the same answers to save the level (backend/server.js
  // adaptiveAbility); these are the levels it produces for these sequences.
  test('result level follows the adaptive ability', () {
    expect(_runQuiz(List.filled(8, true)).level, 'Job-ready');
    expect(_runQuiz(List.filled(8, false)).level, 'Beginner');
    expect(
      _runQuiz([true, false, true, false, true, false, true, false]).level,
      'Intermediate',
    );
    expect(_runQuiz([true, true, true]).level, 'Advanced');
  });
}
