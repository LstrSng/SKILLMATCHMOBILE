import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillmatch/models/job.dart';
import 'package:skillmatch/services/job_skill_matcher.dart';
import 'package:skillmatch/services/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('skillsChanged fires only when the skills list changes', () async {
    SharedPreferences.setMockInitialValues({});
    await SessionStore.updateUser({
      'skills': ['Flutter'],
    });
    final start = SessionStore.skillsChanged.value;

    await SessionStore.updateUser({
      'skills': ['Flutter'],
      'bio': 'new bio',
    });
    expect(SessionStore.skillsChanged.value, start, reason: 'same skills');

    await SessionStore.updateUser({
      'skills': ['Flutter', 'Firebase'],
    });
    expect(SessionStore.skillsChanged.value, start + 1);
  });

  test(
    're-matching after adding a skill moves it from missing to matched',
    () async {
      final job = Job.fromJson({
        'id': 'j1',
        'title': 'Flutter Developer',
        'company': 'Acme',
        'matchedSkills': ['Flutter'],
        'unmatchedSkills': ['Firebase'],
      });
      var jobs = applyOwnSkillMatch(
        jobs: [job],
        user: {
          'skills': ['Flutter'],
        },
      );
      expect(jobs.single.unmatchedSkills, ['Firebase']);
      expect(jobs.single.matchPercentage, 50);

      jobs = applyOwnSkillMatch(
        jobs: jobs,
        user: {
          'skills': ['Flutter', 'Firebase'],
        },
      );
      expect(jobs.single.unmatchedSkills, isEmpty);
      expect(jobs.single.matchPercentage, 100);
    },
  );
}
