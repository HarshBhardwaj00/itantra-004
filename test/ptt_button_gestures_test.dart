import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/presentation/widgets/ptt_button.dart';

void main() {
  group('PttButton Touch & Gesture Precision Tests', () {
    testWidgets('touch outside circular radius does NOT start recording',
        (WidgetTester tester) async {
      var started = false;
      var ended = false;
      var cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PttButton(
                isRecording: false,
                voiceDetected: false,
                onStart: () => started = true,
                onEnd: () => ended = true,
                onCancel: () => cancelled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final pttFinder = find.byType(PttButton);
      final center = tester.getCenter(pttFinder);

      // Tap in the corner of the bounding box (outside the circle radius)
      // The button diameter is at most ~160 (radius ~80).
      // Offset center by (+75, +75) which is distance sqrt(75^2 + 75^2) = 106 > radius (80)
      final cornerOffset = center + const Offset(75, 75);

      final gesture = await tester.startGesture(cornerOffset);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump();

      expect(started, isFalse, reason: 'Touch in corner must never start recording');
      expect(ended, isFalse);
      expect(cancelled, isFalse);
    });

    testWidgets('drag / scroll movement cancels take and does not trigger tap or end',
        (WidgetTester tester) async {
      var started = false;
      var ended = false;
      var cancelled = false;
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PttButton(
                isRecording: false,
                voiceDetected: false,
                onStart: () => started = true,
                onEnd: () => ended = true,
                onCancel: () => cancelled = true,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(PttButton));

      // Pointer down right in the center
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 50));
      expect(started, isTrue);

      // Drag up by 30 pixels (simulating scroll gesture)
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 50));

      expect(cancelled, isTrue, reason: 'Drag movement must trigger cancellation');

      // Release finger
      await gesture.up();
      await tester.pump();

      expect(tapped, isFalse, reason: 'Scroll gesture must never trigger onTap');
      expect(ended, isFalse, reason: 'Scroll gesture must never trigger onEnd');
    });

    testWidgets('accidental micro-brush (< 120ms) cancels and does not trigger tap',
        (WidgetTester tester) async {
      var started = false;
      var ended = false;
      var cancelled = false;
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PttButton(
                isRecording: false,
                voiceDetected: false,
                elapsedMsOverride: () => 50, // Micro-brush 50ms
                onStart: () => started = true,
                onEnd: () => ended = true,
                onCancel: () => cancelled = true,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(PttButton));

      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 40));
      expect(started, isTrue);

      // Release immediately at 40ms without speech
      await gesture.up();
      await tester.pump();

      expect(cancelled, isTrue, reason: 'Micro-brush < 120ms must cancel immediately');
      expect(tapped, isFalse, reason: 'Micro-brush must not trigger tap to record');
      expect(ended, isFalse);
    });

    testWidgets('deliberate hold (>= 350ms) triggers onEnd on release',
        (WidgetTester tester) async {
      var started = false;
      var ended = false;
      var cancelled = false;
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PttButton(
                isRecording: false,
                voiceDetected: false,
                elapsedMsOverride: () => 500, // Hold 500ms
                onStart: () => started = true,
                onEnd: () => ended = true,
                onCancel: () => cancelled = true,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(PttButton));

      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 50));
      expect(started, isTrue);

      await gesture.up();
      await tester.pump();

      expect(ended, isTrue, reason: 'Hold release must trigger onEnd');
      expect(cancelled, isFalse);
      expect(tapped, isFalse);
    });

    testWidgets('deliberate tap (120ms - 350ms) triggers onTap without cancelling',
        (WidgetTester tester) async {
      var started = false;
      var ended = false;
      var cancelled = false;
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PttButton(
                isRecording: false,
                voiceDetected: false,
                elapsedMsOverride: () => 200, // Tap 200ms
                onStart: () => started = true,
                onEnd: () => ended = true,
                onCancel: () => cancelled = true,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(PttButton));

      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 50));
      expect(started, isTrue);

      await gesture.up();
      await tester.pump();

      expect(tapped, isTrue, reason: 'Deliberate tap must trigger onTap');
      expect(cancelled, isFalse, reason: 'Deliberate tap must not cancel recording');
      expect(ended, isFalse);
    });

    testWidgets('second tap while recording triggers onEnd to finish take',
        (WidgetTester tester) async {
      var ended = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PttButton(
                isRecording: true, // Already recording in review mode
                voiceDetected: false,
                onStart: () {},
                onEnd: () => ended = true,
                onCancel: () {},
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(PttButton));

      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump();

      expect(ended, isTrue, reason: 'Tap while recording must trigger onEnd');
    });
  });
}
