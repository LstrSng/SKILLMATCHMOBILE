import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/services/profile_completion.dart';

void main() {
  group('profileCompletionPercent', () {
    test('empty profile scores 0', () {
      expect(profileCompletionPercent({}), 0);
    });

    test('scores the same sections as the Profile Strength meter', () {
      final user = <String, dynamic>{
        'firstName': 'Lester',
        'lastName': 'Sunga',
        'email': 'lester@example.com',
        'skills': ['Dart', 'Flutter', 'SQL'],
        'experience': [
          {'title': 'Mobile Dev', 'company': 'Asi', 'year': '2022-2024'},
        ],
        'education': [
          {'degree': '', 'school': '', 'years': ''},
        ],
        'profile': {
          'skillAssessments': {
            'ba': {
              'level': 'Beginner',
              'correctCount': 1,
              'totalCount': 13,
              'takenAt': '2026-10-01T05:58:00Z',
            },
          },
        },
      };
      // Name 10 + contact 5 + skills 20 + experience 10 + assessment 10.
      // The blank education row doesn't count.
      expect(profileCompletionPercent(user), 55);
    });

    test('a resume adds 20', () {
      final user = <String, dynamic>{
        'profile': {
          'resume': {'name': 'cv.pdf', 'url': 'https://example.com/cv.pdf'},
        },
      };
      expect(profileCompletionPercent(user), 20);
    });
  });
}
