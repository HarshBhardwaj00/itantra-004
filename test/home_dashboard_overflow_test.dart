import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itantra/core/router/app_router.dart';
import 'package:itantra/core/theme/app_theme.dart';
import 'package:itantra/presentation/screens/home_dashboard_screen.dart';

Future<void> pumpDashboard(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HomeDashboardScreen(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  // Every size class the app has to survive: ultra narrow slits, small
  // handsets, mainstream phones, large phones, tablets.
  final testSizes = [
    const Size(160, 400), // Ultra narrow / desktop tile
    const Size(200, 440), // Foldable external / slit
    const Size(240, 480), // Extreme narrow
    const Size(280, 560), // Narrow handset
    const Size(320, 568), // iPhone SE 1st gen
    const Size(360, 640), // Standard Android
    const Size(375, 667), // iPhone SE 2nd gen
    const Size(390, 844), // iPhone 14
    const Size(412, 915), // Pixel 7
    const Size(430, 932), // iPhone 16 Pro Max
    const Size(600, 800), // Tablet / desktop window
    const Size(800, 360), // Landscape phone
  ];

  for (final size in testSizes) {
    testWidgets(
        'renders the landing page at ${size.width}x${size.height} without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpDashboard(tester);

      expect(tester.takeException(), isNull);

      // The brand hero of the reference layout.
      expect(find.text('iTantra'), findsOneWidget);
      expect(find.text('Local Neural Speech & Edge Walkie-Talkie'),
          findsOneWidget);
      expect(find.text('10 Indian Languages'), findsOneWidget);
      expect(find.text('100% Offline'), findsOneWidget);
      expect(find.text('Ultra-Low Latency'), findsOneWidget);

      // The landing CTA and its footnote.
      expect(find.text('Get Started'), findsOneWidget);
      expect(
          find.text('Instant Indian Language Synthesizer · Edge P2P'),
          findsOneWidget);

      // The old dashboard widgets are gone from the entry point.
      expect(find.text('Surfaces'), findsNothing);
      expect(find.text('Field Records'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('no label on the landing page is ever ellipsised or clipped',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpDashboard(tester);

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

  testWidgets('the router opens the landing page on the app entry route',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
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

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeDashboardScreen), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the call to action opens the language picker',
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
    expect(find.text('Select Language'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
