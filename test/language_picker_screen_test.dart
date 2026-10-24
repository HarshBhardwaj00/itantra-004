import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:itantra/core/constants/app_constants.dart';
import 'package:itantra/core/router/app_router.dart';
import 'package:itantra/core/theme/app_theme.dart';
import 'package:itantra/presentation/screens/comms_hub_screen.dart';
import 'package:itantra/presentation/screens/language_picker_screen.dart';

Future<void> pumpPicker(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: const LanguagePickerScreen(),
    ),
  );
  await tester.pump();
  // The local LanguageBloc loads the pack list after a 300 ms delay.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(() {
    // The routed screens talk to the real store, so Hive needs a path.
    final dir = Directory.systemTemp.createTempSync('itantra_picker_test');
    Hive.init(dir.path);
  });

  final testSizes = [
    const Size(120, 480), // Resized narrow desktop / extreme split-view
    const Size(160, 480), // Wearable / compact pane
    const Size(240, 480), // Extreme narrow
    const Size(280, 560), // Narrow handset
    const Size(320, 568), // iPhone SE 1st gen
    const Size(360, 640), // Standard Android
    const Size(375, 667), // iPhone SE 2nd gen
    const Size(390, 844), // iPhone 14
    const Size(412, 915), // Pixel 7
    const Size(430, 932), // iPhone 16 Pro Max
    const Size(600, 800), // Tablet portrait
    const Size(840, 900), // Tablet landscape
    const Size(1200, 800), // Desktop window
  ];

  for (final size in testSizes) {
    testWidgets(
        'renders the language picker at ${size.width}x${size.height} without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPicker(tester);

      expect(tester.takeException(), isNull);

      // The header of the screen.
      expect(find.text('Select Language'), findsOneWidget);
      expect(find.text('Pick your working language'), findsOneWidget);
      expect(find.text('Confirm & Continue'), findsOneWidget);

      // The pack list is loaded with all ten Indian languages.
      expect(find.text('10 of 10 languages'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);
      expect(find.text('Gujarati'), findsOneWidget);
      expect(find.text('Malayalam'), findsOneWidget);
      expect(find.text('Kannada'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('no label on the language picker is ever ellipsised or clipped',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(240, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPicker(tester);

    final offenders = <String>[];
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data;
      if (data == null) continue;
      if (text.overflow == TextOverflow.ellipsis ||
          text.overflow == TextOverflow.clip) {
        offenders.add('$data (${text.overflow})');
      }
      if (text.maxLines != null) {
        offenders.add('$data (maxLines: ${text.maxLines})');
      }
    }

    expect(offenders, isEmpty);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping a language activates it and persists the choice',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPicker(tester);

    await tester.ensureVisible(find.text('Gujarati'));
    await tester.tap(find.text('Gujarati'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
    expect(AppConstants.activeLanguageCode, 'gu_IN');
    expect(AppConstants.activeLanguageName, 'Gujarati');

    // The result caption keeps counting the whole catalogue.
    expect(find.text('10 of 10 languages'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the search field filters the catalogue without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPicker(tester);

    await tester.enterText(find.byType(TextField).first, 'tamil');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('1 of 10 languages'), findsOneWidget);
    expect(find.text('Tamil'), findsOneWidget);
    expect(find.text('Gujarati'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the search field survives the keyboard opening without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPicker(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pump();

    // The Android keyboard takes over the lower half of the screen.
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(find.text('Select Language'), findsOneWidget);
    expect(find.text('Confirm & Continue'), findsOneWidget);

    tester.view.resetViewInsets();
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the router serves the picker on its own route',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: AppRouter.selectLanguage,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.byType(LanguagePickerScreen), findsOneWidget);
    expect(find.text('Select Language'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  test('the router knows the language picker route', () {
    expect(AppRouter.allRoutes, contains(AppRouter.selectLanguage));
    expect(AppRouter.isLanguagePickerRoute(AppRouter.selectLanguage), isTrue);
    expect(AppRouter.isLanguagePickerRoute(AppRouter.home), isFalse);
  });

  testWidgets('the home call to action opens the language picker',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: AppRouter.home,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.byType(LanguagePickerScreen), findsOneWidget);
    expect(find.text('Select Language'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('confirming the language opens the comms hub',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: AppRouter.selectLanguage,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(LanguagePickerScreen), findsOneWidget);

    await tester.ensureVisible(find.text('Confirm & Continue'));
    await tester.tap(find.text('Confirm & Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.byType(LanguagePickerScreen), findsNothing);
    expect(find.byType(CommsHubScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
