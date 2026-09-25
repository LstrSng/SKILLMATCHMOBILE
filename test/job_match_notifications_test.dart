import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillmatch/services/notification_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only new jobs that match the user trigger a notification', () async {
    SharedPreferences.setMockInitialValues({});
    // First sync just records what's already posted.
    await NotificationStore.syncNewJobMatches(
      [const MapEntry('j1', 'Old Job')],
      matchingIds: {'j1'},
    );
    expect(await NotificationStore.load(), isEmpty);

    // A new job with no match: no notification.
    await NotificationStore.syncNewJobMatches([
      const MapEntry('j1', 'Old Job'),
      const MapEntry('j2', 'Unrelated Job'),
    ], matchingIds: {});
    expect(await NotificationStore.load(), isEmpty);

    // A new matching job: notified.
    await NotificationStore.syncNewJobMatches(
      [
        const MapEntry('j1', 'Old Job'),
        const MapEntry('j2', 'Unrelated Job'),
        const MapEntry('j3', 'Flutter Developer'),
      ],
      matchingIds: {'j3'},
    );
    final notes = await NotificationStore.load();
    expect(notes, hasLength(1));
    expect(notes.single.message, contains('Flutter Developer'));
  });
}
