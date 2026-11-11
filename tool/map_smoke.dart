import 'dart:convert';
import 'dart:io';
import 'package:easy_scrap/data/map_service.dart';
import 'package:easy_scrap/domain/map_location.dart';

/// Live provider check using only public demo barangay names, never user data.
Future<void> main() async {
  final service = MapService();
  try {
    final points = <GeoPin>[];
    for (final barangay in ['San Vicente', 'Poblacion', 'Guinobatan']) {
      final point = await service.resolve(
        MapAddress(street: 'Purok 1', barangay: barangay, city: 'Trinidad'),
      );
      if (point == null) throw StateError('No location found for $barangay.');
      points.add(point);
    }
    final route = await service.route([points.first, ...points]);
    stdout.writeln(
      jsonEncode({
        'pins': points.map((pin) => pin.toJson()).toList(),
        'road_metres': route.metres,
        'driving_seconds': route.seconds,
        'geometry_points': route.geometry.length,
      }),
    );
  } finally {
    service.client.close();
  }
}
