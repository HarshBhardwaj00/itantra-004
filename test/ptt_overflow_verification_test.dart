import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/core/router/app_router.dart';
import 'package:itantra/core/theme/app_theme.dart';
import 'package:itantra/presentation/screens/comms_hub_screen.dart';
import 'package:itantra/presentation/widgets/comms_composer_bar.dart';
import 'package:itantra/presentation/widgets/comms_identity_bar.dart';
import 'package:itantra/presentation/widgets/recorded_audio_card.dart';

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
    (call) async => 1,
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
  final testDevices = <String, Size>{
    'narrow-compact (280x500)': const Size(280, 500),
    'small-iphone-se (320x568)': const Size(320, 568),
    'small-android (320x640)': const Size(320, 640),
    'standard-phone (360x740)': const Size(360, 740),
    'medium-phone (390x844)': const Size(390, 844),
    'large-phone (412x915)': const Size(412, 915),
    'tablet-portrait (800x1280)': const Size(800, 1280),
    'tablet-landscape (1024x768)': const Size(1024, 768),
  };

  group('RecordedAudioCard Zero-Overflow Verification', () {
    for (final entry in testDevices.entries) {
      for (final scale in [1.0, 1.3, 1.6]) {
        testWidgets(
            'RecordedAudioCard with active clip at ${entry.key} scale $scale',
            (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: RecordedAudioCard(
                      hasClip: true,
                      durationLabel: '0:14',
                      statusLabel: 'Ready to send',
                      isSending: false,
                      wasSent: false,
                      previewText: 'Sector 4 radio check — loud and clear.',
                      onDiscard: () {},
                      onSend: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Recorded Audio'), findsOneWidget);
          expect(find.text('Discard'), findsOneWidget);
          expect(find.text('Send Audio'), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  });

  group('CommsIdentityBar Zero-Overflow Verification', () {
    for (final entry in testDevices.entries) {
      for (final scale in [1.0, 1.3, 1.6]) {
        testWidgets(
            'CommsIdentityBar at ${entry.key} scale $scale',
            (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: CommsIdentityBar(
                      title: 'iTantra',
                      subtitle: 'Hindi · hi',
                      statusLabel: 'Mesh Active',
                      statusActive: true,
                      onBack: () {},
                      onSubtitleTap: () {},
                      trailing: const SizedBox(width: 36, height: 36),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('iTantra'), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  });

  group('CommsComposerBar Zero-Overflow Verification', () {
    for (final entry in testDevices.entries) {
      for (final scale in [1.0, 1.3, 1.6]) {
        testWidgets(
            'CommsComposerBar at ${entry.key} scale $scale',
            (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final controller = TextEditingController(text: 'Tactical message payload');
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CommsComposerBar(
                      controller: controller,
                      onSend: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Send'), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    for (final width in [76.4, 94.4, 120.0, 160.0]) {
      for (final scale in [1.0, 1.3, 1.6, 2.0]) {
        testWidgets(
            'CommsComposerBar survives tight width $width scale $scale without overflow',
            (tester) async {
          tester.view.physicalSize = const Size(800, 600);
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final controller =
              TextEditingController(text: 'Tactical message payload');
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: CommsComposerBar(
                      controller: controller,
                      onSend: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Send'), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  });

  group('Unified CommsHubScreen Full Flow Zero-Overflow Verification', () {
    for (final entry in testDevices.entries) {
      testWidgets('renders hub sender and receiver at ${entry.key} without overflow',
          (tester) async {
        _mockChannels(tester);
        tester.view.physicalSize = entry.value;
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

        expect(tester.takeException(), isNull);
        expect(find.text('Recorded Audio'), findsOneWidget);

        // Switch to receiver mode
        await tester.tap(find.text('Receiver'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('Signal Vector'), findsNothing);

        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
