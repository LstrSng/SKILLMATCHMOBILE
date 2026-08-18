import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/widgets/otp_code_field.dart';

void main() {
  testWidgets('OtpCodeField renders and accepts digit input without throwing', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpCodeField(controller: controller, autofocus: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(6));

    await tester.enterText(fields.at(0), '1');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(controller.text, '1');
  });

  testWidgets(
    'typing all 6 digits fills the controller and fires onSubmitted',
    (tester) async {
      final controller = TextEditingController();
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpCodeField(
              controller: controller,
              onSubmitted: (v) => submitted = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      for (var i = 0; i < 6; i++) {
        await tester.enterText(fields.at(i), '$i');
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      expect(controller.text, '012345');
      expect(submitted, '012345');
    },
  );

  testWidgets('backspace on an empty box clears and focuses the previous box', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OtpCodeField(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '9');
    await tester.pump();
    expect(controller.text, '9');

    // Focus the second (empty) box and press backspace.
    await tester.tap(fields.at(1));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controller.text, '');
  });

  testWidgets('setting the controller text from outside updates the boxes', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OtpCodeField(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    controller.text = '654321';
    await tester.pump();

    expect(tester.takeException(), isNull);
    final fields = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      final field = tester.widget<TextField>(fields.at(i));
      expect(field.controller!.text, '654321'[i]);
    }
  });
}
