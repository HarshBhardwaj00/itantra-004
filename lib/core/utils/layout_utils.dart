import 'package:flutter/widgets.dart';

/// Clamps [value] into the inclusive `[min, max]` window.
double clampDouble(double value, double min, double max) {
  if (value <= min) return min;
  if (value >= max) return max;
  return value;
}

/// Device width classes used to pick breakpoints across the whole app.
///
/// * [small]  — width < 360 dp (compact handsets)
/// * [medium] — 360 dp … 414 dp (the mainstream phone band)
/// * [large]  — width > 414 dp (plus tablets and landscape windows)
enum AppBreakpoint {
  small,
  medium,
  large;

  factory AppBreakpoint.fromWidth(double width) {
    if (width < 360.0) return AppBreakpoint.small;
    if (width <= 414.0) return AppBreakpoint.medium;
    return AppBreakpoint.large;
  }

  bool get isSmall => this == AppBreakpoint.small;

  bool get isLarge => this == AppBreakpoint.large;
}

/// Central responsive typography scale.
///
/// Every value is derived from the live screen width and clamped so nothing
/// ever drops below the 11 sp legibility floor and nothing ever explodes on
/// tablets. No widget should hard-code a font size.
class AppType {
  AppType._();

  /// Screen header (page titles, app bar titles).
  static double header(double width) => clampDouble(width * 0.052, 18.0, 22.0);

  /// Section header (card titles).
  static double section(double width) => clampDouble(width * 0.042, 15.0, 17.0);

  /// Metric / stat counters (distance, latency, big numbers).
  static double metric(double width) => clampDouble(width * 0.065, 20.0, 26.0);

  /// Item titles (job, course, candidate, call-sign).
  static double itemTitle(double width) => clampDouble(width * 0.038, 14.0, 16.0);

  /// Metadata and subtitles.
  static double meta(double width) => clampDouble(width * 0.033, 12.0, 14.0);

  /// Badges, chips and pill labels.
  static double badge(double width) => clampDouble(width * 0.030, 11.0, 12.0);

  /// Primary button labels.
  static double button(double width) => clampDouble(width * 0.036, 13.0, 15.0);

  /// Monospace technical read-outs (coordinates, byte counts).
  static double mono(double width) => clampDouble(width * 0.032, 12.0, 14.0);
}

/// Shared spacing rhythm derived from the device width.
class AppSpacing {
  AppSpacing._();

  /// Horizontal screen gutter.
  static double gutter(double width) => clampDouble(width * 0.045, 12.0, 20.0);

  /// Gap between two stacked sections.
  static double section(double height) => clampDouble(height * 0.018, 10.0, 18.0);

  /// Gap between two inline widgets.
  static double inline(double width) => clampDouble(width * 0.025, 8.0, 12.0);

  /// Corner radius for the big tactical cards.
  static double cardRadius(double width) => clampDouble(width * 0.06, 20.0, 26.0);

  /// Inner padding of the big tactical cards.
  static double cardPad(double width) => clampDouble(width * 0.05, 18.0, 26.0);

  /// Inner padding of nested surfaces.
  static double innerPad(double width) => clampDouble(width * 0.04, 14.0, 20.0);

  /// Corner radius of nested surfaces.
  static double innerRadius(double width) => clampDouble(width * 0.04, 14.0, 18.0);

  /// Gap between chips inside a [Wrap].
  static double chip(double width) => clampDouble(width * 0.02, 8.0, 12.0);
}

/// Converts any dynamic string into a human readable Title Case.
///
/// `flutter developer` becomes `Flutter Developer` — no raw lowercase ever
/// reaches the screen.
String toTitleCase(String value) {
  if (value.trim().isEmpty) return value;
  final words = value.trim().split(RegExp(r'[\s_\-/]+'));
  final buffer = StringBuffer();
  for (final word in words) {
    if (word.isEmpty) continue;
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(word[0].toUpperCase());
    buffer.write(word.substring(1));
  }
  return buffer.isEmpty ? value : buffer.toString();
}

/// Shortens a label to a compact synonym so it always fits on one line
/// without ever resorting to an ellipsis.
///
/// The full meaning is preserved by the caller (usually through a caption or
/// a tooltip), the visible string stays readable.
String compactSynonym(String value, {int maxWords = 2}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length <= maxWords) return trimmed;
  return words.take(maxWords).join(' ');
}

/// Convenience accessors for the live viewport.
extension ViewportX on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  double get screenHeight => MediaQuery.sizeOf(this).height;

  AppBreakpoint get breakpoint => AppBreakpoint.fromWidth(screenWidth);

  double get gutter => AppSpacing.gutter(screenWidth);

  double get bottomInset => MediaQuery.paddingOf(this).bottom;

  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;

  bool get keyboardVisible => MediaQuery.viewInsetsOf(this).bottom > 0;
}
