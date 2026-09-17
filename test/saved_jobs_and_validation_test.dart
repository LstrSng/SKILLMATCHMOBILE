import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillmatch/pages/register_page.dart';
import 'package:skillmatch/services/saved_jobs_store.dart';
import 'package:skillmatch/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SavedJobsStore Tests', () {
    test('toggles and persists bookmarked job IDs', () async {
      expect(await SavedJobsStore.isSaved('job_123'), isFalse);

      final added = await SavedJobsStore.toggle('job_123');
      expect(added.contains('job_123'), isTrue);
      expect(await SavedJobsStore.isSaved('job_123'), isTrue);

      final removed = await SavedJobsStore.toggle('job_123');
      expect(removed.contains('job_123'), isFalse);
      expect(await SavedJobsStore.isSaved('job_123'), isFalse);
    });
  });

  group('RegisterPage Real-Time Password Validation Tests', () {
    testWidgets('shows live password length and match indicators', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildLightTheme(), home: const RegisterPage()),
      );
      await tester.pumpAndSettle();

      // Initially, no password indicators shown
      expect(find.text('At least 8 characters'), findsNothing);
      expect(find.text('Passwords match'), findsNothing);
      expect(find.text('Passwords do not match'), findsNothing);

      // Find password text field
      final passwordFields = find.byType(TextField);
      // The register form has First Name(0), Last Name(1), Email(2), Phone(3), Password(4), Confirm Password(5)
      expect(passwordFields, findsAtLeastNWidgets(6));

      // Enter a 4-char password into the password field (index 4)
      await tester.enterText(passwordFields.at(4), 'pass');
      await tester.pumpAndSettle();

      // Length indicator should now appear
      expect(find.text('At least 8 characters'), findsOneWidget);

      // Enter matching 4-char password in confirm field (index 5)
      await tester.enterText(passwordFields.at(5), 'pass');
      await tester.pumpAndSettle();

      // Passwords match indicator should show
      expect(find.text('Passwords match'), findsOneWidget);

      // Enter non-matching password in confirm field
      await tester.enterText(passwordFields.at(5), 'different');
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
