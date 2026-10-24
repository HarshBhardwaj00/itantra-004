import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../presentation/screens/comms_log_screen.dart';
import '../../presentation/screens/comms_hub_screen.dart';
import '../../presentation/screens/home_dashboard_screen.dart';
import '../../presentation/screens/language_manager_screen.dart';
import '../../presentation/screens/language_picker_screen.dart';
import '../../presentation/screens/radio_manager_screen.dart';
import '../../presentation/screens/tactical_radar_screen.dart';

/// Which half of the unified comms hub is on screen.
///
/// The hub keeps [sender] and [receiver] alive inside a single
/// [IndexedStack] so switching between them is instant and never loses the
/// live transcript, the replay queue or the UDP listener state.
enum CommsMode {
  sender,
  receiver;

  CommsMode get toggled =>
      this == CommsMode.sender ? CommsMode.receiver : CommsMode.sender;
}

/// Destinations exposed by the tactical dock that lives on the secondary
/// surfaces (radar, comms log, radio manager, language manager).
enum DockDestination {
  sender,
  receiver,
  radar,
  logs,
  radio,
}

/// Shared handle on the hub mode.
///
/// The secondary surfaces own a dock, so they need a way to ask the unified
/// hub to open in a given mode without stacking a second copy of the hub.
class CommsHubState {
  CommsHubState._();

  static final ValueNotifier<CommsMode> mode =
      ValueNotifier<CommsMode>(CommsMode.sender);
}

class AppRouter {
  AppRouter._();

  /// Home dashboard (Screen 0) — the entry point of the app.
  static const String home = '/';

  /// Alias of the home dashboard, handy for deep links.
  static const String dashboard = '/dashboard';

  /// Language pack selection (Screen 1B) — the onboarding step that sits
  /// between the home dashboard and the unified comms hub.
  static const String selectLanguage = '/select-language';

  /// Unified sender + receiver hub (Screen 2 and Screen 6 in one shell).
  static const String comms = '/comms';

  /// The hub opened in receiver mode.
  static const String receiver = '/receiver';

  /// Legacy alias of the hub in sender mode.
  static const String legacyHome = '/home';

  static const String radar = '/radar';
  static const String logs = '/logs';
  static const String radio = '/radio';
  static const String language = '/language';

  /// Every route the app can reach.
  static const List<String> allRoutes = <String>[
    home,
    dashboard,
    selectLanguage,
    comms,
    receiver,
    legacyHome,
    radar,
    logs,
    radio,
    language,
  ];

  /// True when [name] belongs to the unified hub.
  static bool isHubRoute(String? name) =>
      name == comms || name == receiver || name == legacyHome;

  /// True when [name] belongs to the home dashboard.
  static bool isDashboardRoute(String? name) =>
      name == home || name == dashboard;

  /// True when [name] belongs to the language pack selection screen.
  static bool isLanguagePickerRoute(String? name) => name == selectLanguage;

  /// Route that hosts the given hub mode.
  static String hubRouteFor(CommsMode mode) =>
      mode == CommsMode.sender ? comms : receiver;

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
      case dashboard:
        return _fadeRoute(settings, const HomeDashboardScreen());
      case selectLanguage:
        return _fadeRoute(settings, const LanguagePickerScreen());
      case comms:
      case legacyHome:
        return _fadeRoute(
          settings,
          const CommsHubScreen(initialMode: CommsMode.sender),
        );
      case receiver:
        return _fadeRoute(
          settings,
          const CommsHubScreen(initialMode: CommsMode.receiver),
        );
      case radar:
        return _fadeRoute(settings, const TacticalRadarScreen());
      case logs:
        return _fadeRoute(settings, const CommsLogScreen());
      case radio:
        return _fadeRoute(settings, const RadioManagerScreen());
      case language:
        return _fadeRoute(settings, const LanguageManagerScreen());
      default:
        return _fadeRoute(settings, const HomeDashboardScreen());
    }
  }

  static PageRouteBuilder _fadeRoute(RouteSettings settings, Widget page) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: child,
        );
      },
    );
  }
}

/// Navigation helpers that keep the router stack flat.
extension AppRouterNav on BuildContext {
  /// Replaces the current route with [route].
  void replaceRoute(String route) {
    HapticFeedback.lightImpact();
    Navigator.of(this).pushReplacementNamed(route);
  }

  /// Pushes [route] on top of the current route.
  void pushRoute(String route) {
    HapticFeedback.lightImpact();
    Navigator.of(this).pushNamed(route);
  }

  /// Pops the current route if possible, otherwise stays put.
  void popRoute() {
    final navigator = Navigator.of(this);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  /// Opens the home dashboard and clears everything that was above it.
  void openDashboard() {
    HapticFeedback.lightImpact();
    Navigator.of(this).pushNamedAndRemoveUntil(
      AppRouter.home,
      (route) => route.isFirst,
    );
  }

  /// Opens the unified hub in the requested mode.
  void openComms(CommsMode mode) {
    HapticFeedback.lightImpact();
    CommsHubState.mode.value = mode;
    Navigator.of(this).pushNamed(AppRouter.hubRouteFor(mode));
  }

  /// Opens the language pack selection screen.
  ///
  /// This is the step that sits between the home dashboard and the comms
  /// hub: `Home → Select Language → Push-To-Talk / Receiver`.
  void openLanguagePicker() {
    HapticFeedback.lightImpact();
    Navigator.of(this).pushNamed(AppRouter.selectLanguage);
  }

  /// Handles a tactical dock tap.
  ///
  /// Sender and receiver always resolve back to the single unified hub,
  /// while sibling surfaces replace each other so the stack never grows.
  void goToDock(DockDestination destination) {
    HapticFeedback.lightImpact();
    final navigator = Navigator.of(this);

    switch (destination) {
      case DockDestination.sender:
      case DockDestination.receiver:
        CommsHubState.mode.value = destination == DockDestination.sender
            ? CommsMode.sender
            : CommsMode.receiver;
        navigator.popUntil(
          (route) => route.isFirst || AppRouter.isHubRoute(route.settings.name),
        );
      case DockDestination.radar:
        navigator.pushReplacementNamed(AppRouter.radar);
      case DockDestination.logs:
        navigator.pushReplacementNamed(AppRouter.logs);
      case DockDestination.radio:
        navigator.pushReplacementNamed(AppRouter.radio);
    }
  }
}
