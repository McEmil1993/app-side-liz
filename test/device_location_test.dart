import 'package:easy_scrap/data/device_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class TestLocationPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  int requests = 0, fixes = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    fixes++;
    return Position(
      latitude: 10.079,
      longitude: 124.343,
      timestamp: DateTime(2026),
      accuracy: 12,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  final original = GeolocatorPlatform.instance;
  late TestLocationPlatform platform;
  setUp(() {
    platform = TestLocationPlatform();
    GeolocatorPlatform.instance = platform;
  });
  tearDown(() => GeolocatorPlatform.instance = original);
  test('Denied access does not generate a location or read GPS', () async {
    platform.permission = LocationPermission.denied;
    await expectLater(DeviceLocationService.current(), throwsStateError);
    expect(platform.requests, 1);
    expect(platform.fixes, 0);
  });
  test('Disabled location services do not request permission', () async {
    platform.enabled = false;
    await expectLater(DeviceLocationService.current(), throwsStateError);
    expect(platform.requests, 0);
    expect(platform.fixes, 0);
  });
  test(
    'User location preserves the device coordinates and accuracy label',
    () async {
      final pin = await DeviceLocationService.current();
      expect(pin.latitude, 10.079);
      expect(pin.longitude, 124.343);
      expect(pin.source, 'gps');
      expect(pin.label, contains('12 m'));
      expect(platform.fixes, 1);
    },
  );
}
