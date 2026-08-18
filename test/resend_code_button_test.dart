import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/widgets/resend_code_button.dart';

void main() {
  testWidgets('starts in cooldown and disables the button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResendCodeButton(onResend: () async {}, cooldownSeconds: 5),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Resend code (5s)'), findsOneWidget);

    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('becomes tappable once the cooldown finishes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResendCodeButton(onResend: () async {}, cooldownSeconds: 2),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('Resend code'), findsOneWidget);
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('tapping calls onResend and restarts the cooldown', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResendCodeButton(
            onResend: () async {
              calls++;
            },
            cooldownSeconds: 2,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));

    await tester.tap(find.byType(TextButton));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(calls, 1);
    expect(find.text('Resend code (2s)'), findsOneWidget);
  });
}
