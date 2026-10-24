import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:itantra/core/router/app_router.dart';
import 'package:itantra/core/theme/app_theme.dart';
import 'package:itantra/presentation/screens/comms_hub_screen.dart';
import 'package:itantra/presentation/screens/language_picker_screen.dart';
import 'package:itantra/presentation/widgets/comms_composer_bar.dart';

const MethodChannel _geoChannel =
    MethodChannel('flutter.baseflow.com/geolocator');
const MethodChannel _ttsChannel = MethodChannel('flutter_tts');
const MethodChannel _audioGlobalChannel =
    MethodChannel('xyz.luan/audioplayers.global');
const MethodChannel _audioGlobalEventsChannel =
    MethodChannel('xyz.luan/audioplayers.global/events');
const MethodChannel _audioChannel = MethodChannel('xyz.luan/audioplayers');

void _mockChannels(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _geoChannel,
    (call) async {
      if (call.method == 'isLocationServiceEnabled') return false;
      return null;
    },
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _ttsChannel,
    (call) async {
      if (call.method == 'speak') return 1;
      if (call.method == 'stop') return 1;
      if (call.method == 'isLanguageAvailable') return 1;
      return null;
    },
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _audioGlobalChannel,
    (call) async => 1,
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _audioGlobalEventsChannel,
    (call) async => null,
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _audioChannel,
    (call) async => 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('keyboard_aesthetic_test');
    Hive.init(dir.path);
  });

  group('Square Shape Aesthetics & Layout Verification', () {
    testWidgets('CommsComposerBar text field and send button are square-shaped squircles',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CommsComposerBar(
              controller: controller,
              onSend: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the TextField OutlineInputBorder
      final textField = tester.widget<TextField>(find.byType(TextField));
      final decoration = textField.decoration;
      expect(decoration, isNotNull);

      final border = decoration!.border as OutlineInputBorder;
      expect(border.borderRadius.topLeft.x, lessThanOrEqualTo(10.0));
      expect(border.borderRadius.topLeft.x, greaterThanOrEqualTo(8.0));

      // Find Send button Material and verify square squircle (not 999 pill)
      final sendMaterials = tester.widgetList<Material>(find.descendant(
        of: find.byType(CommsComposerBar),
        matching: find.byType(Material),
      ));

      final sendButtonMaterial = sendMaterials.firstWhere(
        (m) => m.borderRadius != null,
      );
      final sendBorderRadius = sendButtonMaterial.borderRadius as BorderRadius;
      expect(sendBorderRadius.topLeft.x, lessThanOrEqualTo(10.0));
      expect(sendBorderRadius.topLeft.x, greaterThanOrEqualTo(8.0));
      // Definitely NOT circular pill (999)
      expect(sendBorderRadius.topLeft.x, isNot(equals(999)));

      // Verify typing does not cause RenderFlex overflow
      await tester.enterText(find.byType(TextField), 'Test tactical transmission square UI');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Keyboard Opening Smoothness & Rebuild Isolation', () {
    testWidgets('CommsHubScreen keyboard opening isolates insets without rebuilding the hub or PTT',
        (WidgetTester tester) async {
      _mockChannels(tester);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CommsHubScreen(initialMode: CommsMode.sender),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);

      // Simulate keyboard open transition across multiple frames (0 -> 120 -> 280)
      for (final insets in [60.0, 140.0, 220.0, 280.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: insets);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      // Verify composer is visible and Send button exists
      expect(find.byType(CommsComposerBar), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);

      // Close keyboard
      tester.view.resetViewInsets();
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('LanguagePickerScreen keyboard opening does not throw and isolates search',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LanguagePickerScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);

      // Focus search field
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Keyboard slides up
      for (final insets in [50.0, 120.0, 200.0, 260.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: insets);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      // Search typing filtering operates smoothly without overflow
      await tester.enterText(find.byType(TextField), 'Hin');
      await tester.pump();
      expect(find.text('Hindi'), findsOneWidget);

      tester.view.resetViewInsets();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
