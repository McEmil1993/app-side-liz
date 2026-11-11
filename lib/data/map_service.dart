import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/map_config.dart';
import '../domain/map_location.dart';

/// Small demo traffic only. One shared cache and serialized geocoder queue.
class MapService {
  static const _headers = <String, String>{
    'Accept': 'application/json',
    if (!bool.fromEnvironment('dart.library.js_interop'))
      'User-Agent': 'EasyScrapCapstone/1.0',
  };
  static final instance = MapService();
  final http.Client client;
  MapService({http.Client? client}) : client = client ?? http.Client();
  final _addresses = <String, Future<GeoPin?>>{};
  final _searches = <String, Future<List<dynamic>>>{};
  final _routes = <String, Future<RoadRoute>>{};
  final _reverse = <String, Future<ReverseAddress?>>{};
  final _municipalityPostcodes = <String, String>{};
  Future<void> _queue = Future.value();

  Future<String?> reverse(GeoPin pin) async =>
      (await reverseAddress(pin))?.label;

  /// Resolve a settled pin before confirmation; cached by coordinate.
  Future<ReverseAddress?> reverseAddress(GeoPin pin) {
    if (!pin.valid) {
      throw StateError('Choose a valid pin before finding its address.');
    }
    final key =
        '${pin.latitude.toStringAsFixed(6)},${pin.longitude.toStringAsFixed(6)}';
    return _reverse.putIfAbsent(key, () async {
      final previous = _queue;
      final pending = () async {
        await previous;
        final uri = Uri.parse(MapConfig.reverseGeocoder).replace(
          queryParameters: {
            'lat': pin.latitude.toString(),
            'lon': pin.longitude.toString(),
            'limit': '5',
            'lang': 'en',
            'radius': '1',
          },
        );
        final response = await client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw StateError(
            'Address lookup is unavailable. Retry or confirm the barangay manually.',
          );
        }
        final features =
            (jsonDecode(response.body) as Map<String, dynamic>)['features']
                as List;
        if (features.isEmpty) return null;
        final properties = Map<String, dynamic>.from(
          (features.first as Map<String, dynamic>)['properties'] as Map,
        );
        // Nearby buildings often carry the barangay under `city`; a village
        // feature can supply its actual name without mistaking a POI for it.
        for (final feature in features) {
          final p = (feature as Map)['properties'] as Map;
          if (p['osm_key'] == 'place' &&
              [
                'village',
                'suburb',
                'neighbourhood',
                'quarter',
              ].contains(p['osm_value'])) {
            properties.putIfAbsent('locality', () => p['name']);
            properties.putIfAbsent('postcode', () => p['postcode']);
            break;
          }
        }
        final parts = <String>[];
        final street = [
          properties['housenumber'],
          properties['street'],
        ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
        for (final raw in [
          properties['name'],
          street,
          properties['district'],
          properties['locality'],
          properties['city'],
          properties['county'],
          properties['state'],
          properties['country'],
        ]) {
          if (raw is String &&
              raw.trim().isNotEmpty &&
              !parts.any(
                (part) => part.toLowerCase() == raw.trim().toLowerCase(),
              )) {
            parts.add(raw.trim());
          }
        }
        return parts.isEmpty
            ? null
            : ReverseAddress(parts.join(', '), street, properties);
      }();
      _queue = pending.then<void>(
        (_) async {
          await Future<void>.delayed(const Duration(seconds: 1));
        },
        onError: (Object _) async {
          await Future<void>.delayed(const Duration(seconds: 1));
        },
      );
      try {
        return await pending;
      } catch (_) {
        _reverse.remove(key);
        rethrow;
      }
    });
  }

  Future<GeoPin?> resolve(
    MapAddress address,
  ) => _addresses.putIfAbsent(address.key, () async {
    // OSM place node 9128438026, retrieved through Photon. This is a barangay
    // centre, never a fabricated Purok 1 / house coordinate.
    if (address.barangayCode == '071244017' ||
        (address.barangay.toLowerCase() == 'san vicente' &&
            address.city.toLowerCase() == 'trinidad')) {
      return const GeoPin(
        10.0726067,
        124.3227073,
        source: 'barangay',
        label: 'San Vicente, Trinidad, Bohol',
      );
    }
    try {
      final centre = await resolveMunicipality(address.city);
      if (centre == null || address.barangay.trim().isEmpty) return centre;
      final candidates = await _search(address.barangay, placeOnly: true);
      final nearby = candidates.cast<Map<String, dynamic>>().where((item) {
        final p = item['properties'] as Map<String, dynamic>;
        final point = _point(item, 'barangay');
        return '${p['name']}'.toLowerCase() == address.barangay.toLowerCase() &&
            point != null &&
            (point.latitude - centre.latitude).abs() < .12 &&
            (point.longitude - centre.longitude).abs() < .12 &&
            // Proximity alone cannot prove barangay membership: neighboring
            // municipalities share barangay names. Use the city centre instead
            // when the provider has no matching municipality component.
            ([p['city'], p['county']].whereType<String>().any(
                  (name) => _normalName(name) == _normalName(address.city),
                ) ||
                // Photon omits municipality components for many Bohol villages.
                // A matching municipal postal code disambiguates equal names;
                // explicit conflicting municipality fields are never overridden.
                ![
                      p['city'],
                      p['county'],
                    ].whereType<String>().any((v) => v.trim().isNotEmpty) &&
                    '${p['postcode'] ?? ''}'.isNotEmpty &&
                    p['postcode'].toString() ==
                        _municipalityPostcodes[_normalName(address.city)]);
      }).toList();
      nearby.sort((a, b) {
        double score(Map<String, dynamic> item) {
          final point = _point(item, 'barangay')!;
          return (point.latitude - centre.latitude).abs() +
              (point.longitude - centre.longitude).abs();
        }

        return score(a).compareTo(score(b));
      });
      return nearby.isNotEmpty ? _point(nearby.first, 'barangay') : centre;
    } catch (_) {
      _addresses.remove(address.key);
      rethrow;
    }
  });

  static String _normalName(String value) => value
      .toLowerCase()
      .replaceFirst(RegExp(r'^(city of|municipality of)\s+'), '')
      .trim();

  /// Exact Bohol place match, never the first nearby search result.
  Future<GeoPin?> resolveMunicipality(String name) async {
    if (name.trim().isEmpty) return null;
    final results = await _search('$name, Bohol', placeOnly: true);
    for (final raw in results) {
      final feature = raw as Map<String, dynamic>;
      final p = feature['properties'] as Map<String, dynamic>;
      if (_normalName('${p['name'] ?? ''}') != _normalName(name)) continue;
      if (p['state'] != null && _normalName('${p['state']}') != 'bohol') {
        continue;
      }
      if (p['countrycode'] != null &&
          '${p['countrycode']}'.toLowerCase() != 'ph') {
        continue;
      }
      if (p['osm_value'] != null &&
          ![
            'town',
            'city',
            'municipality',
            'administrative',
          ].contains(p['osm_value'])) {
        continue;
      }
      if (p['type'] == 'district' || p['type'] == 'locality') continue;
      final point = _point(feature, 'municipality');
      if (point != null) {
        if (p['postcode'] is String && (p['postcode'] as String).isNotEmpty) {
          _municipalityPostcodes[_normalName(name)] = p['postcode'] as String;
        }
        return point;
      }
    }
    return null;
  }

  Future<String?> municipalityPostcode(String name) async {
    final key = _normalName(name);
    if (!_municipalityPostcodes.containsKey(key)) {
      await resolveMunicipality(name);
    }
    return _municipalityPostcodes[key];
  }

  GeoPin? _point(Map<String, dynamic> feature, String source) {
    final coordinates =
        (feature['geometry'] as Map<String, dynamic>?)?['coordinates'];
    if (coordinates is! List ||
        coordinates.length < 2 ||
        coordinates[0] is! num ||
        coordinates[1] is! num) {
      return null;
    }
    final properties = feature['properties'] as Map<String, dynamic>;
    final pin = GeoPin(
      (coordinates[1] as num).toDouble(),
      (coordinates[0] as num).toDouble(),
      source: source,
      label: '${properties['name'] ?? ''}, ${properties['state'] ?? 'Bohol'}',
    );
    return pin.valid &&
            pin.latitude >= 9.3 &&
            pin.latitude <= 10.4 &&
            pin.longitude >= 123.6 &&
            pin.longitude <= 125
        ? pin
        : null;
  }

  Future<List<dynamic>> _search(String text, {bool placeOnly = false}) {
    final key = '$text|$placeOnly';
    return _searches.putIfAbsent(key, () async {
      final previous = _queue;
      final pending = () async {
        await previous;
        final uri = Uri.parse(MapConfig.geocoder).replace(
          queryParameters: {
            'q': text,
            'bbox': '123.6,9.3,125.0,10.4',
            'limit': '20',
            'lang': 'en',
            if (placeOnly) 'osm_tag': 'place',
          },
        );
        final response = await client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          throw StateError(
            'Address search is unavailable (${response.statusCode}). You can set the pin manually.',
          );
        }
        return (jsonDecode(response.body) as Map<String, dynamic>)['features']
            as List<dynamic>;
      }();
      // Rate pacing is provider protection, not a simulated loading delay.
      _queue = pending.then<void>(
        (_) async {
          await Future<void>.delayed(const Duration(seconds: 1));
        },
        onError: (Object _) async {
          await Future<void>.delayed(const Duration(seconds: 1));
        },
      );
      try {
        return await pending;
      } catch (_) {
        _searches.remove(key);
        rethrow;
      }
    });
  }

  Future<RoadRoute> route(List<GeoPin> stops, {bool retry = false}) {
    if (stops.length < 2 || stops.any((pin) => !pin.valid)) {
      throw StateError(
        'At least two valid points are needed for a road route.',
      );
    }
    if (stops.length > 25) {
      throw StateError(
        'Please split this route into groups of at most 24 pickups.',
      );
    }
    final coordinates = stops
        .map(
          (point) =>
              '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}',
        )
        .join(';');
    if (retry) _routes.remove(coordinates);
    return _routes.putIfAbsent(coordinates, () async {
      try {
        final uri =
            Uri.parse(
              '${MapConfig.router.replaceFirst(RegExp(r'/+$'), '')}/$coordinates',
            ).replace(
              queryParameters: {
                'overview': 'full',
                'geometries': 'geojson',
                'steps': 'false',
              },
            );
        final response = await client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 25));
        if (response.statusCode != 200) {
          throw StateError('Road routing is unavailable. Please retry.');
        }
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = body['routes'] as List<dynamic>?;
        if (body['code'] != 'Ok' || routes == null || routes.isEmpty) {
          throw StateError('No drivable route found. Check the pickup pins.');
        }
        final route = routes.first as Map<String, dynamic>;
        final line =
            ((route['geometry'] as Map<String, dynamic>)['coordinates'] as List)
                .map(
                  (point) => GeoPin(
                    (point[1] as num).toDouble(),
                    (point[0] as num).toDouble(),
                    source: 'road',
                  ),
                )
                .toList();
        if (line.length < 2 || line.any((point) => !point.valid)) {
          throw StateError(
            'The route response did not contain a valid road path.',
          );
        }
        return RoadRoute(
          geometry: line,
          metres: (route['distance'] as num).toDouble(),
          seconds: (route['duration'] as num).toDouble(),
        );
      } catch (_) {
        _routes.remove(coordinates);
        rethrow;
      }
    });
  }
}
