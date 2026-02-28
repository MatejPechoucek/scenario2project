import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scenario2project/main.dart';

void main() {
  testWidgets('HomePage displays welcome text', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Welcome to the Scenario 2 Project!'), findsOneWidget);
    expect(
      find.text(
        'This is a Flutter template app that runs on both Android and iOS.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.flutter_dash), findsOneWidget);
  });
}
