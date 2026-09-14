import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillmatch/services/applications_api.dart';
import 'package:skillmatch/services/job_roles_data.dart';
import 'package:skillmatch/services/jobs_api.dart';
import 'package:skillmatch/services/pathway_links_data.dart';
import 'package:skillmatch/services/profile_api.dart';
import 'package:skillmatch/services/session_store.dart';
import 'package:skillmatch/services/skill_assessment_bank.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Job and Application Caching Tests', () {
    test(
      'getCachedJobsRaw retrieves cached jobs from SharedPreferences',
      () async {
        final dummyJobs = [
          {
            'id': 'job-101',
            'title': 'Flutter Developer',
            'company': 'Tech Corp',
          },
          {
            'id': 'job-102',
            'title': 'Backend Developer',
            'company': 'Data Inc',
          },
        ];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cache.jobs.raw', jsonEncode(dummyJobs));

        final result = await getCachedJobsRaw();
        expect(result.length, equals(2));
        expect(result[0]['title'], equals('Flutter Developer'));
        expect(memoryCachedJobs, isNotNull);
        expect(memoryCachedJobs!.length, equals(2));
      },
    );

    test(
      'getCachedMyApplications retrieves cached applications per user',
      () async {
        await SessionStore.save(
          token: 'test-token',
          user: {'_id': 'user_abc123', 'email': 'test@example.com'},
        );

        final dummyApps = [
          {'id': 'app-1', 'jobId': 'job-101', 'status': 'Pending'},
        ];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'cache.applications.user_abc123',
          jsonEncode(dummyApps),
        );

        final result = await getCachedMyApplications();
        expect(result.length, equals(1));
        expect(result[0]['jobId'], equals('job-101'));
        expect(memoryCachedApplications, isNotNull);
        expect(memoryCachedApplications!.length, equals(1));
      },
    );
    test(
      'resetJobRolesCache and resetPsfAssessmentBankCache clear caches safely',
      () {
        expect(() => resetJobRolesCache(), returnsNormally);
        expect(() => resetPsfAssessmentBankCache(), returnsNormally);
        expect(() => resetPathwayLinksCache(), returnsNormally);
        expect(() => clearProfileCache(), returnsNormally);
      },
    );
  });
}
