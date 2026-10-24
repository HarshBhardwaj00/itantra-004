import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:itantra/core/constants/app_constants.dart';
import 'package:itantra/core/theme/app_theme.dart';
import 'package:itantra/presentation/blocs/language/language_bloc.dart';
import 'package:itantra/presentation/blocs/language/language_event.dart';
import 'package:itantra/presentation/blocs/language/language_state.dart';
import 'package:itantra/presentation/screens/language_manager_screen.dart';

Future<void> pumpLanguageScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: const LanguageManagerScreen(),
    ),
  );
  await tester.pump();
  // Allow LanguageBloc._onInitialize 300ms delay to complete
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final testSizes = [
    const Size(320, 568),
    const Size(360, 640),
    const Size(375, 667),
    const Size(390, 844),
    const Size(412, 915),
    const Size(430, 932),
  ];

  for (final size in testSizes) {
    testWidgets('renders LanguageManagerScreen at ${size.width}x${size.height}',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpLanguageScreen(tester);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('pops back cleanly when chevron back button is tapped without !_debugLocked crash',
      (WidgetTester tester) async {
    dynamic popResult;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popResult = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanguageManagerScreen()),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    // Tap to open LanguageManagerScreen
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Language Manager'), findsOneWidget);

    // Tap back button
    final backFinder = find.byIcon(LucideIcons.chevronLeft);
    expect(backFinder, findsOneWidget);
    await tester.tap(backFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify it returned to the root and passed true without throwing !_debugLocked
    expect(find.text('Open'), findsOneWidget);
    expect(popResult, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pops back cleanly on system back gesture without !_debugLocked crash',
      (WidgetTester tester) async {
    dynamic popResult;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popResult = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanguageManagerScreen()),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Language Manager'), findsOneWidget);

    // Simulate system back gesture
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Open'), findsOneWidget);
    expect(popResult, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('LanguageBloc initializes with activeLanguageCode from AppConstants instead of hardcoded Hindi', () async {
    AppConstants.activeLanguageCode = 'en_IN';
    AppConstants.activeLanguageName = 'English';

    final bloc = LanguageBloc();
    bloc.add(const LanguageInitialize());

    await expectLater(
      bloc.stream,
      emitsInOrder([
        predicate<LanguageState>((s) => s.status == LanguageStatus.loading),
        predicate<LanguageState>((s) =>
            s.status == LanguageStatus.loaded &&
            s.activeLanguage?.code == 'en_IN' &&
            s.languagePacks.firstWhere((p) => p.code == 'en_IN').availability == LanguageAvailability.active &&
            s.languagePacks.firstWhere((p) => p.code == 'hi_IN').availability == LanguageAvailability.installed),
      ]),
    );
    await bloc.close();

    // Reset back to Hindi
    AppConstants.activeLanguageCode = 'hi_IN';
    AppConstants.activeLanguageName = 'Hindi';
  });

  test('LanguageBloc isolates testingLanguageCode to the requested language pack only', () async {
    final bloc = LanguageBloc();
    bloc.add(const LanguageTestVoice('mr_IN'));

    await expectLater(
      bloc.stream,
      emitsInOrder([
        predicate<LanguageState>((s) =>
            s.isTestingVoice && s.testingLanguageCode == 'mr_IN'),
        predicate<LanguageState>((s) =>
            !s.isTestingVoice && s.testingLanguageCode == null),
      ]),
    );
    await bloc.close();
  });
}
