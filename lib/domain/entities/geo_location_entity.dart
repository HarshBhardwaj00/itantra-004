class GeoLocationEntity {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double altitudeMeters;
  final DateTime capturedAt;

  const GeoLocationEntity({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.altitudeMeters = 0.0,
    required this.capturedAt,
  });

  factory GeoLocationEntity.none() => GeoLocationEntity(
        latitude: 0.0,
        longitude: 0.0,
        accuracyMeters: -1.0,
        capturedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  bool get hasFix => accuracyMeters >= 0.0;

  String get chipLabel => hasFix
      ? '${latitude.abs().toStringAsFixed(2)} ${latitude >= 0 ? "N" : "S"}'
      : 'No Fix';

  String get accuracyLabel =>
      hasFix ? '±${accuracyMeters.round()} m' : 'Accuracy n/a';

  String get altitudeLabel =>
      hasFix ? 'Altitude ${altitudeMeters.round()} m' : 'Altitude n/a';
}
