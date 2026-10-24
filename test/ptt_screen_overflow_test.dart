import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:itantra/core/theme/app_theme.dart';
import 'package:itantra/presentation/screens/home_ptt_screen.dart';

const MethodChannel _geoChannel =
    MethodChannel('flutter.baseflow.com/geolocator');

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

Future<void> pumpPtt(WidgetTester tester) async {
  _mockGeolocator(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HomePttScreen(),
    ),
  );
  await tester.pump();
  // Allow progressive engine bootstrap timers to settle
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final testSizes = [
    const Size(320, 568), // iPhone SE 1st gen / Small phone
    const Size(320, 640), // Small Android
    const Size(360, 640), // Standard compact Android
    const Size(360, 740), // Compact Android
    const Size(375, 667), // iPhone SE 2nd/3rd gen / Medium phone
    const Size(390, 844), // iPhone 12/13/14 / Medium phone
    const Size(412, 915), // Pixel 7 / Large phone
    const Size(430, 932), // iPhone 15/16 Pro Max / Large phone
  ];

  for (final size in testSizes) {
    testWidgets('renders HomePttScreen at ${size.width}x${size.height} without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPtt(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Hold to Talk'), findsOneWidget);
      expect(find.text('Last Message'), findsOneWidget);
      expect(find.text('Recorded Audio'), findsOneWidget);
      expect(find.text('No clip yet — hold the mic'), findsOneWidget);

      // Dispose widget and cancel periodic telemetry timer
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('SOS banner toggles and renders without overflow on small phone (320x568)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPtt(tester);

    // Tap SOS button (siren icon)
    final sosFinder = find.byIcon(LucideIcons.siren);
    expect(sosFinder, findsOneWidget);
    await tester.ensureVisible(sosFinder);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(sosFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SOS Armed'), findsOneWidget);
    expect(find.text('Next send gets SOS flag 0x02. Peers see it as an alert.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tap again to disarm
    await tester.ensureVisible(sosFinder);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(sosFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('SOS Armed'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('SOS banner toggles and renders without overflow on medium phone (390x844)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPtt(tester);

    final sosFinder = find.byIcon(LucideIcons.siren);
    expect(sosFinder, findsOneWidget);
    await tester.tap(sosFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SOS Armed'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('SOS banner toggles and renders without overflow on large phone (430x932)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPtt(tester);

    final sosFinder = find.byIcon(LucideIcons.siren);
    expect(sosFinder, findsOneWidget);
    await tester.tap(sosFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SOS Armed'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
