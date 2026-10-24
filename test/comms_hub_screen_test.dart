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

/// The hub hosts both surfaces, so the test pumps the real routed widget.
Future<void> pumpHub(
  WidgetTester tester, {
  CommsMode mode = CommsMode.sender,
  bool withTalkBloc = false,
}) async {
  _mockChannels(tester);

  Widget app = CommsHubScreen(initialMode: mode);
  if (withTalkBloc) {
    app = BlocProvider<TalkBloc>(
      create: (_) => TalkBloc(),
      child: app,
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: app,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final testSizes = [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ];

  for (final size in testSizes) {
    testWidgets(
        'unified hub renders sender surface at ${size.width}x${size.height} without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpHub(tester);

      expect(tester.takeException(), isNull);

      // Shared shell.
      expect(find.text('iTantra'), findsOneWidget);
      expect(find.text('Sender'), findsOneWidget);
      expect(find.text('Receiver'), findsOneWidget);

      // Sender surface.
      expect(find.text('Hold to Talk'), findsOneWidget);
      expect(find.text('Recorded Audio'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'unified hub renders receiver surface at ${size.width}x${size.height} without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpHub(tester, mode: CommsMode.receiver);

      expect(tester.takeException(), isNull);

      // Receiver surface.
      expect(find.text('Signal Vector'), findsNothing);
      expect(find.text('Listen Pipeline'), findsNothing);
      expect(find.text('Quick Reply'), findsNothing);
      expect(find.text('Replay Queue'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('sender and receiver switch from the same screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpHub(tester);

    // Sender surface is up.
    expect(find.text('Hold to Talk'), findsOneWidget);
    expect(find.text('Signal Vector'), findsNothing);

    // Switch to the receiver from the bottom switcher.
    await tester.tap(find.text('Receiver'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Signal Vector'), findsNothing);
    expect(find.text('Quick Reply'), findsNothing);
    expect(find.text('Replay Queue'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Switch back.
    await tester.tap(find.text('Sender'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Hold to Talk'), findsOneWidget);
    expect(find.text('Recorded Audio'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('data labels in the hub are never ellipsised, clipped or line-capped', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpHub(tester);

    final offenders = <String>[];
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data;
      if (data == null) continue;

      final maxLines = text.maxLines;
      final isSingleLineBarLabel = maxLines == 1;

      if (text.overflow == TextOverflow.clip) {
        // Any label ever clipped is an offender.
        offenders.add('$data (${text.overflow})');
      }
      if (text.overflow == TextOverflow.ellipsis && !isSingleLineBarLabel) {
        // Data labels must always render in full. Only the static,
        // single-line identity-bar labels (brand title, language line) may
        // cap at one row to keep the bar linear under accessibility text
        // scales.
        offenders.add('$data (ellipsis)');
      }
      if (maxLines != null && maxLines > 1) {
        offenders.add('$data (maxLines: $maxLines)');
      }
    }

    expect(offenders, isEmpty);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('composer sends a text message and clears the field', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpHub(tester, withTalkBloc: true);

    final field = find.byType(TextField);
    expect(field, findsOneWidget);

    await tester.enterText(field, 'Flood rising at sector 4');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    // Flush the stop-and-wait ACK window so no timer survives the teardown.
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);

    // The transcript and the last-message card now carry the packet payload…
    expect(find.text('Flood rising at sector 4'), findsWidgets);

    // …and the composer field is empty again.
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, isEmpty);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('composer survives the keyboard opening without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpHub(tester);

    await tester.enterText(find.byType(TextField), 'Sector 4 flooding fast');
    await tester.pump();

    // Simulate the Android keyboard taking over the lower half of the screen.
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);

    tester.view.resetViewInsets();
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
  });
}
