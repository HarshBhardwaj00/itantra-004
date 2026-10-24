// Smoke test of the application shell.
//
// The home dashboard is the entry point of the app.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:itantra/main.dart';

void main() {
  setUpAll(() {
    // The app boots Hive in main(); the test harness skips main(), so the
    // store path is set up here.
    final dir = Directory.systemTemp.createTempSync('itantra_widget_test');
    Hive.init(dir.path);
  });

  testWidgets('App renders the home dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ITantraApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('iTantra'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Ultra-Low Latency'), findsOneWidget);
  });

  testWidgets('App boots straight to the dashboard without a setup screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ITantraApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The tactical setup surface is gone — its landmarks must not show up.
    expect(find.text('Device Call-Sign'), findsNothing);
    expect(find.text('Select Role'), findsNothing);
    expect(find.text('Enter Tactical Comms'), findsNothing);
  });
}
