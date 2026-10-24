import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:itantra/core/theme/app_theme.dart';
import 'package:itantra/presentation/screens/comms_log_screen.dart';
import 'package:itantra/presentation/screens/radio_manager_screen.dart';

/// The secondary surfaces are the two screens that are not hosted by the
/// unified hub. They still have to hold on the smallest supported phone, so
/// they are rendered at every breakpoint here.
Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: screen,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('itantra_secondary_test');
    Hive.init(dir.path);
  });

  final testSizes = [
    const Size(240, 480),
    const Size(320, 568),
    const Size(360, 640),
    const Size(430, 932),
  ];

  for (final size in testSizes) {
    testWidgets(
        'the radio manager renders at ${size.width}x${size.height} without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpScreen(tester, const RadioManagerScreen());

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'the comms log renders at ${size.width}x${size.height} without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpScreen(tester, const CommsLogScreen());

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('no label of the radio manager is ever ellipsised or clipped',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(240, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpScreen(tester, const RadioManagerScreen());

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
}
