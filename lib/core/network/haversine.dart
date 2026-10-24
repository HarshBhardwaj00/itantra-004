import 'dart:math' as math;

/// Spherical trigonometry helpers behind Screen 3 (Tactical Radar).
///
/// Network concept: **Spherical Trigonometry (Haversine & Bearing Math)**.
/// The great-circle surface distance and the forward azimuth between the
/// receiver fix and the sender fix are derived purely from the IEEE-754
/// coordinates unpacked out of the inbound packet payload.
class GeoMath {
  GeoMath._();

  /// Mean Earth radius in metres (WGS-84 spherical approximation).
  static const double earthRadiusM = 6371000.0;

  static const List<String> compassPoints = <String>[
    'NORTH',
    'NORTH-EAST',
    'EAST',
    'SOUTH-EAST',
    'SOUTH',
    'SOUTH-WEST',
    'WEST',
    'NORTH-WEST',
  ];

  static double toRadians(double degrees) => degrees * math.pi / 180.0;

  static double toDegrees(double radians) => radians * 180.0 / math.pi;

  /// Wraps any angle into the [0, 360) range.
  static double normalize(double degrees) {
    var value = degrees % 360.0;
    if (value < 0) value += 360.0;
    return value;
  }

  /// Haversine great-circle surface distance in metres.
  static double distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = toRadians(lat2 - lat1);
    final dLon = toRadians(lon2 - lon1);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRadians(lat1)) *
            math.cos(toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusM * 2.0 * math.atan2(math.sqrt(h), math.sqrt(1.0 - h));
  }

  /// Forward azimuth in degrees measured from true north, clockwise.
  static double bearingDegrees(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final phi1 = toRadians(lat1);
    final phi2 = toRadians(lat2);
    final deltaLon = toRadians(lon2 - lon1);

    final y = math.sin(deltaLon) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLon);

    return normalize(toDegrees(math.atan2(y, x)));
  }

  /// 8-point compass label for a bearing (e.g. `NORTH-EAST`).
  static String compassPoint(double bearing) {
    final index = ((normalize(bearing) + 22.5) ~/ 45) % 8;
    return compassPoints[index];
  }

  /// Short human distance label: `820 M`, `1.7 KM`, `5 KM`.
  static String formatDistance(double meters) {
    if (meters.isNaN || meters.isInfinite || meters < 0) return '0 M';
    if (meters < 995.0) return '${meters.round()} M';
    final km = (meters / 1000.0).toStringAsFixed(1);
    return '${km.endsWith('.0') ? km.substring(0, km.length - 2) : km} KM';
  }

  /// Whole-degree label that never renders `360°`.
  static String formatDegrees(double degrees) {
    final value = normalize(degrees).round() % 360;
    return '$value\u00B0';
  }
}
