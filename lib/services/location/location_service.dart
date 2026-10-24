import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../domain/entities/geo_location_entity.dart';

class LocationService {
  LocationService._();

  static Future<GeoLocationEntity> current(
      {Duration timeLimit = const Duration(seconds: 4)}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return GeoLocationEntity.none();

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return GeoLocationEntity.none();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: timeLimit,
        ),
      );

      return GeoLocationEntity(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        altitudeMeters: position.altitude,
        capturedAt: DateTime.now(),
      );
    } catch (_) {
      return GeoLocationEntity.none();
    }
  }

  /// Continuous receiver fix.
  ///
  /// Emits a fresh [GeoLocationEntity] every time the device moves more than
  /// [distanceFilter] metres, so the radar can keep range and bearing live
  /// without polling. The stream stays silent (never throws) when location
  /// services are disabled or permission is denied, and closes cleanly when
  /// the listener is cancelled — which also keeps widget tests hermetic.
  static Stream<GeoLocationEntity> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 5,
  }) {
    late StreamController<GeoLocationEntity> controller;
    StreamSubscription<Position>? subscription;
    var cancelled = false;

    Future<void> start() async {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (cancelled || !serviceEnabled) {
          if (!controller.isClosed) await controller.close();
          return;
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (cancelled ||
            permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (!controller.isClosed) await controller.close();
          return;
        }

        subscription = Geolocator.getPositionStream(
          locationSettings: LocationSettings(
            accuracy: accuracy,
            distanceFilter: distanceFilter,
          ),
        ).listen(
          (position) {
            if (cancelled || controller.isClosed) return;
            controller.add(GeoLocationEntity(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracyMeters: position.accuracy,
              altitudeMeters: position.altitude,
              capturedAt: DateTime.now(),
            ));
          },
          onError: (Object _) {},
        );
      } catch (_) {
        if (!controller.isClosed) await controller.close();
      }
    }

    controller = StreamController<GeoLocationEntity>(
      onListen: () => unawaited(start()),
      onCancel: () async {
        cancelled = true;
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }
}
