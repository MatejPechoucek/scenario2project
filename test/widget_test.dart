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

  group('DietPage', () {
    Future<void> openDietPage(WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.byIcon(Icons.apple));
      await tester.pumpAndSettle();
    }

    testWidgets('shows Diet Plan heading', (WidgetTester tester) async {
      await openDietPage(tester);
      expect(find.text('Diet Plan'), findsOneWidget);
    });

    testWidgets('shows all meal cards', (WidgetTester tester) async {
      await openDietPage(tester);
      expect(find.text('Healthy Gain'), findsOneWidget);
      expect(find.text('Manage Deficiency'), findsOneWidget);
      expect(find.text('Muscle Gain'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('shows all calculator fields', (WidgetTester tester) async {
      await openDietPage(tester);
      expect(find.text('Height (CM)'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Activity Level'), findsOneWidget);
    });

    testWidgets('spinner fields start at 0', (WidgetTester tester) async {
      await openDietPage(tester);
      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      for (final field in fields) {
        expect(field.controller?.text, '0');
      }
    });

    testWidgets('up arrow increments spinner value', (WidgetTester tester) async {
      await openDietPage(tester);
      await tester.tap(find.byIcon(Icons.arrow_drop_up).first);
      await tester.pump();
      final firstField = tester.widgetList<TextField>(find.byType(TextField)).first;
      expect(firstField.controller?.text, '1');
    });

    testWidgets('down arrow does not go below 0', (WidgetTester tester) async {
      await openDietPage(tester);
      await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
      await tester.pump();
      final firstField = tester.widgetList<TextField>(find.byType(TextField)).first;
      expect(firstField.controller?.text, '0');
    });

    testWidgets('Activity Level does not exceed max of 9', (WidgetTester tester) async {
      await openDietPage(tester);
      final upArrows = find.byIcon(Icons.arrow_drop_up);
      // Tap the last up arrow (Activity Level) 10 times
      for (int i = 0; i < 10; i++) {
        await tester.tap(upArrows.last);
        await tester.pump();
      }
      final lastField = tester.widgetList<TextField>(find.byType(TextField)).last;
      expect(lastField.controller?.text, '9');
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
