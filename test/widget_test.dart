import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temp_v2/main.dart';

void main() {
  testWidgets('shows entry choices, then sign up form, then chat experience', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TemptationsApp());

    expect(find.text('Temptations'), findsOneWidget);
    expect(find.text('Start your experience'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byIcon(Icons.phone_iphone_rounded), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.byIcon(Icons.phone_iphone_rounded), findsOneWidget);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('Stream setup needed'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Write a message'), findsNothing);
  });
}
