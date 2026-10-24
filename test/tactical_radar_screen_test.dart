import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/core/theme/app_theme.dart';
import 'package:itantra/presentation/screens/tactical_radar_screen.dart';

const MethodChannel _geoChannel =
    MethodChannel('flutter.baseflow.com/geolocator');

/// geolocator has no platform implementation in widget tests, and an
/// unhandled platform future never settles inside fake-async — mock the
/// channel so the fix lock falls back to the offline seed immediately.
void _mockGeolocator(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _geoChannel,
    (call) async {
      if (call.method == 'isLocationServiceEnabled') return false;
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_geoChannel, null);
  });
}

/// Pumps the screen with bounded frames only — the blip pulse controller
/// repeats forever, so `pumpAndSettle` must never be used here.
Future<void> pumpRadar(WidgetTester tester) async {
  _mockGeolocator(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: const TacticalRadarScreen(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  testWidgets('renders hero banner and telemetry cards at 320x640',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpRadar(tester);

    expect(find.text('1.7 KM \u2022 NORTH-EAST (45\u00B0)'), findsOneWidget);
    expect(find.text('PEER LOCK'), findsOneWidget);
    expect(find.text('Direction Dial'), findsOneWidget);
    expect(find.text('Recenter'), findsOneWidget);
    expect(find.text('Grid View'), findsOneWidget);
    expect(find.text('Span 3 KM'), findsWidgets);
    expect(find.text('My Position'), findsOneWidget);
    expect(find.text('Sender Position'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders complete layout at 360x740', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpRadar(tester);

    expect(find.text('1.7 KM \u2022 NORTH-EAST (45\u00B0)'), findsOneWidget);
    expect(find.textContaining('28.6139\u00B0 N'), findsWidgets);
    expect(find.textContaining('77.2090\u00B0 E'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Grid View toggle swaps dial for vector grid without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpRadar(tester);
    expect(find.text('Direction Dial'), findsOneWidget);

    // The control row sits below the fold on the smallest phone — scroll it
    // into view first, which also proves the layout is scroll-safe.
    await tester.ensureVisible(find.text('Grid View'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text('Grid View'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Vector Grid'), findsOneWidget);
    expect(find.text('Radar View'), findsOneWidget);
    expect(find.text('Direction Dial'), findsNothing);

    await tester.ensureVisible(find.text('Radar View'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text('Radar View'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Direction Dial'), findsOneWidget);
    expect(find.text('Grid View'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Recenter keeps the screen alive and data visible',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpRadar(tester);

    await tester.ensureVisible(find.text('Recenter'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text('Recenter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('1.7 KM \u2022 NORTH-EAST (45\u00B0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dock tabs are visible and never clipped', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpRadar(tester);

    expect(find.text('Sender'), findsOneWidget);
    expect(find.text('Radar'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);
    expect(find.text('Radio'), findsOneWidget);
    expect(find.text('Receiver'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
