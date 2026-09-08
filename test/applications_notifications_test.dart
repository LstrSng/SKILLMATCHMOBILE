import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/job_application.dart';
import 'package:skillmatch/services/notification_store.dart';

void main() {
  group('AppNotification Model Tests', () {
    test('serializes and deserializes type, targetId, and actionLabel correctly', () {
      final now = DateTime.now();
      final notification = AppNotification(
        id: 'test-notif-1',
        title: 'Application Update',
        message: 'Your status moved to Interview.',
        createdAt: now,
        type: 'application',
        targetId: 'app-123',
        actionLabel: 'View Application',
        isRead: false,
      );

      final json = notification.toJson();
      expect(json['id'], equals('test-notif-1'));
      expect(json['type'], equals('application'));
      expect(json['targetId'], equals('app-123'));
      expect(json['actionLabel'], equals('View Application'));
      expect(json['isRead'], isFalse);

      final deserialized = AppNotification.fromJson(json);
      expect(deserialized.id, equals('test-notif-1'));
      expect(deserialized.title, equals('Application Update'));
      expect(deserialized.type, equals('application'));
      expect(deserialized.targetId, equals('app-123'));
      expect(deserialized.actionLabel, equals('View Application'));
    });

    test('copyWith properly updates isRead and fields', () {
      final notification = AppNotification(
        id: 'test-2',
        title: 'Job Match',
        message: 'New job available',
        createdAt: DateTime.now(),
        type: 'job_match',
      );

      final read = notification.copyWith(isRead: true);
      expect(read.isRead, isTrue);
      expect(read.title, equals('Job Match'));
      expect(read.type, equals('job_match'));
    });
  });

  group('JobApplication Timeline Model Tests', () {
    test('parses statusHistory and snapshot correctly', () {
      final json = {
        'id': 'app-99',
        'jobId': 'job-42',
        'jobTitle': 'Senior Flutter Engineer',
        'company': 'Tech Corp',
        'createdAt': '2026-08-20T10:00:00Z',
        'status': 'Interview',
        'statusHistory': [
          {
            'status': 'Applied',
            'date': '2026-08-20T10:00:00Z',
            'note': 'Application received',
          },
          {
            'status': 'Screening',
            'date': '2026-08-22T14:30:00Z',
            'note': 'Recruiter phone screen passed',
          },
          {
            'status': 'Interview',
            'date': '2026-08-24T09:15:00Z',
            'note': 'Technical interview scheduled',
          }
        ],
        'jobSnapshot': {
          'title': 'Senior Flutter Engineer',
          'company': 'Tech Corp',
          'matchPercentage': 92,
        }
      };

      final app = JobApplication.fromJson(json);
      expect(app.id, equals('app-99'));
      expect(app.jobTitle, equals('Senior Flutter Engineer'));
      expect(app.company, equals('Tech Corp'));
      expect(app.currentStatus, equals('Interview'));
      expect(app.statusHistory.length, equals(3));
      expect(app.statusHistory[0].status, equals('Applied'));
      expect(app.statusHistory[1].status, equals('Screening'));
      expect(app.statusHistory[2].note, equals('Technical interview scheduled'));
      expect(app.jobSnapshot['matchPercentage'], equals(92));
    });

    test('verifies canWithdraw is false once Hired, Rejected, or Withdrawn', () {
      JobApplication createAppWithStatus(String status) {
        return JobApplication.fromJson({
          'id': 'app-status-test',
          'jobId': 'job-1',
          'jobTitle': 'Software Engineer',
          'company': 'SkillMatch',
          'status': status,
        });
      }

      // Active / In-progress states can be withdrawn
      for (final activeStatus in ['Applied', 'Screening', 'Interview', 'Interviewing', 'Offer']) {
        final app = createAppWithStatus(activeStatus);
        expect(app.canWithdraw, isTrue, reason: '$activeStatus should be withdrawable');
        expect(app.isClosed, isFalse);
      }

      // Hired cannot be withdrawn
      final hiredApp = createAppWithStatus('Hired');
      expect(hiredApp.isHired, isTrue);
      expect(hiredApp.isClosed, isTrue);
      expect(hiredApp.canWithdraw, isFalse, reason: 'Hired applicants cannot withdraw');

      // Rejected cannot be withdrawn
      final rejectedApp = createAppWithStatus('Rejected');
      expect(rejectedApp.isRejected, isTrue);
      expect(rejectedApp.isClosed, isTrue);
      expect(rejectedApp.canWithdraw, isFalse, reason: 'Rejected applicants cannot withdraw');

      // Withdrawn cannot be withdrawn again
      final withdrawnApp = createAppWithStatus('Withdrawn');
      expect(withdrawnApp.isWithdrawn, isTrue);
      expect(withdrawnApp.isClosed, isTrue);
      expect(withdrawnApp.canWithdraw, isFalse, reason: 'Already withdrawn applicants cannot withdraw');
    });
  });
}
