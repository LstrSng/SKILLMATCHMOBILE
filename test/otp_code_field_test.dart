import 'package:flutter/material.dart';
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

    final field = find.byType(TextField);
    expect(field, findsOneWidget);

    await tester.enterText(field, '1');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(controller.text, '1');
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == '1'),
      findsOneWidget,
    );
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

      final field = find.byType(TextField);
      await tester.enterText(field, '012345');
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(controller.text, '012345');
      expect(submitted, '012345');
      for (var i = 0; i < 6; i++) {
        expect(
          find.byWidgetPredicate((w) => w is Text && w.data == '$i'),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('backspace clears the last digit', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OtpCodeField(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    await tester.enterText(field, '9');
    await tester.pump();
    expect(controller.text, '9');
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == '9'),
      findsOneWidget,
    );

    await tester.enterText(field, '');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controller.text, '');
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == '9'),
      findsNothing,
    );
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
    for (var ch in '654321'.split('')) {
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == ch),
        findsOneWidget,
      );
    }
  });

  testWidgets('enforces digits-only filter and 6-digit max length', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OtpCodeField(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    await tester.enterText(field, '1a2b3c456789');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controller.text, '123456');
  });
}
