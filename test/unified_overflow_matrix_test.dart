import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/core/router/app_router.dart';
import 'package:itantra/core/theme/app_theme.dart';
import 'package:itantra/presentation/blocs/talk/talk_bloc.dart';
import 'package:itantra/presentation/screens/comms_hub_screen.dart';

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

/// Pumps the unified hub through the real widget tree so the identity bar,
/// the sender and receiver panels, the composer and the mode switcher are
/// all laid out inside one [IndexedStack].
///
/// Both hub panels are kept alive by the [IndexedStack], so pumping the
/// sender surface also lays out the receiver surface at the same size.
Future<void> pumpHub(
  WidgetTester tester, {
  CommsMode mode = CommsMode.sender,
}) async {
  _mockChannels(tester);

  await tester.pumpWidget(
    BlocProvider<TalkBloc>(
      create: (_) => TalkBloc(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: CommsHubScreen(initialMode: mode),
      ),
    ),
  );
  await tester.pump();
  // Allow the progressive engine bootstrap timers to settle.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  // From the smallest zoomed Android handset to portrait tablets.
  final deviceSizes = <String, Size>{
    'zoomed-small': const Size(240, 640),
    'small-android': const Size(300, 600),
    'iphone-se': const Size(320, 568),
    'compact-android': const Size(360, 640),
    'iphone-14': const Size(390, 844),
    'pixel-fold-inner-wide': const Size(480, 1000),
    'tablet-portrait': const Size(800, 1280),
    'tablet-landscape': const Size(1024, 600),
  };

  for (final entry in deviceSizes.entries) {
    for (final double textScale in <double>[1.0, 1.3, 2.0]) {
      testWidgets(
        'hub survives ${entry.key} '
        '${entry.value.width}x${entry.value.height} '
        'at ${textScale}x text scale without overflow',
        (WidgetTester tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await pumpHub(tester, mode: CommsMode.sender);

          expect(tester.takeException(), isNull);

          expect(find.text('iTantra'), findsOneWidget);
          expect(find.text('Recorded Audio'), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'hub survives 320x568 at 1.3x scale with the bold-text setting on',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpHub(tester, mode: CommsMode.sender);

      expect(tester.takeException(), isNull);
      expect(find.text('Recorded Audio'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'composer survives the keyboard opening on a zoomed handset (240x640)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(240, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpHub(tester, mode: CommsMode.sender);

      await tester.enterText(find.byType(TextField), 'Sector 4 flooding fast');
      await tester.pump();

      // Keyboard takes over the lower half of the viewport.
      tester.view.viewInsets = const FakeViewPadding(bottom: 320.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);

      tester.view.resetViewInsets();
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'mode switching survives a zoomed handset (240x640) at 1.3x scale',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(240, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpHub(tester, mode: CommsMode.sender);

      await tester.tap(find.text('Receiver'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
      expect(find.text('Signal Vector'), findsNothing);

      await tester.tap(find.text('Sender'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
      expect(find.text('Recorded Audio'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    },
  );
}
