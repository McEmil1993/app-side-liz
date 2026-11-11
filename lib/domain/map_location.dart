import 'location.dart';

class GeoPin {
  final double latitude, longitude;
  final String source, label;
  final LocationSelection? location;
  final String street;
  const GeoPin(
    this.latitude,
    this.longitude, {
    this.source = 'manual',
    this.label = '',
    this.location,
    this.street = '',
  });
  bool get confirmed => source == 'manual';
  bool get valid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
  Map<String, Object> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'source': source,
    'label': label,
    if (location != null) ...location!.toJson(),
    if (location != null) 'street_purok': street,
  };
  static GeoPin? fromMessage(Map<String, dynamic> value) {
    if (value['lat'] is! num || value['lng'] is! num) return null;
    final pin = GeoPin(
      (value['lat'] as num).toDouble(),
      (value['lng'] as num).toDouble(),
    );
    return pin.valid ? pin : null;
  }
}

class MapAddress {
  final String street, barangay, city, barangayCode;
  const MapAddress({
    required this.street,
    required this.barangay,
    required this.city,
    this.barangayCode = '',
  });
  String get area => '$barangay, $city, Bohol';
  String get full => [
    street,
    barangay,
    city,
    'Bohol',
    'Philippines',
  ].where((part) => part.trim().isNotEmpty).join(', ');
  String get key => full.trim().toLowerCase();
}

class RoadRoute {
  final List<GeoPin> geometry;
  final double metres, seconds;
  const RoadRoute({
    required this.geometry,
    required this.metres,
    required this.seconds,
  });
}

/// Components returned by reverse geocoding, not an administrative boundary proof.
class ReverseAddress {
  final String label, street;
  final Map<String, dynamic> properties;
  const ReverseAddress(this.label, this.street, this.properties);
}
