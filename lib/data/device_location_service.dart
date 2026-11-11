import 'package:geolocator/geolocator.dart';
import '../domain/map_location.dart';

/// One foreground location fix, requested only after tapping Use my location.
class DeviceLocationService {
  static Future<GeoPin> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on your device location services first.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location access was denied. Allow it in your browser or device settings, or use your profile starting point.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    final pin = GeoPin(
      position.latitude,
      position.longitude,
      source: 'gps',
      label: 'GPS location (accuracy ±${position.accuracy.round()} m)',
    );
    if (!pin.valid) {
      throw StateError('Your device did not return a valid location.');
    }
    return pin;
  }
}
