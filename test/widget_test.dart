import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scenario2project/main.dart';

void main() {
  group('MainShell navigation', () {
    testWidgets('starts on Home tab', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      expect(find.text('Welcome to the Scenario 2 Project!'), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('tapping Profile tab switches to ProfilePage',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      expect(find.text('third button'), findsOneWidget);
    });

    testWidgets('tapping Home tab returns to HomePage',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This is a Flutter template app that runs on both Android and iOS.',
        ),
        findsOneWidget,
      );
    });
  });

  group('HomePage', () {
    testWidgets('displays welcome text and icon', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      expect(find.text('Welcome to the Scenario 2 Project!'), findsOneWidget);
      expect(
        find.text(
          'This is a Flutter template app that runs on both Android and iOS.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Start building your feature on your own branch!'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.flutter_dash), findsOneWidget);
    });

    testWidgets('displays both buttons', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      expect(find.text('Click me'), findsOneWidget);
      expect(find.text('another button'), findsOneWidget);
    });

    testWidgets('ElevatedButton is tappable without throwing',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      await tester.tap(find.text('Click me'));
      await tester.pump();
    });

    testWidgets('TextButton is tappable without throwing',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      await tester.tap(find.text('another button'));
      await tester.pump();
    });
  });

  group('ProfilePage', () {
    setUp(() async {});

    testWidgets('displays flutter_dash icon', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.flutter_dash), findsOneWidget);
    });

    testWidgets('displays welcome text', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to the Scenario 2 Project!'), findsOneWidget);
    });

    testWidgets('displays third button and it is tappable',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      expect(find.text('third button'), findsOneWidget);
      await tester.tap(find.text('third button'));
      await tester.pump();
    });
  });

  group('MyApp', () {
    testWidgets('has correct app title', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.title, 'Scenario 2 Project');
    });

    testWidgets('uses Material 3', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.theme?.useMaterial3, isTrue);
    });

    testWidgets('AppBar is present with correct title',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Scenario 2 Project'), findsOneWidget);
    });
  });
}
