import 'dart:convert';
import 'package:easy_scrap/data/map_service.dart';
import 'package:easy_scrap/data/demo_recycling_repository.dart';
import 'package:easy_scrap/domain/map_location.dart';
import 'package:easy_scrap/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'Guinobatan without municipality components uses Trinidad postal evidence, not its town centre',
    () async {
      final service = MapService(
        client: MockClient((request) async {
          final citySearch =
              request.url.queryParameters['q'] == 'Trinidad, Bohol';
          return http.Response(
            jsonEncode({
              'features': citySearch
                  ? [
                      {
                        'properties': {
                          'name': 'Trinidad',
                          'state': 'Bohol',
                          'osm_value': 'town',
                          'postcode': '6324',
                        },
                        'geometry': {
                          'coordinates': [124.3430533, 10.0792217],
                        },
                      },
                    ]
                  : [
                      {
                        'properties': {
                          'name': 'Guinobatan',
                          'state': 'Bohol',
                          'postcode': '6315',
                        },
                        'geometry': {
                          'coordinates': [124.4097615, 10.0435122],
                        },
                      },
                      {
                        'properties': {
                          'name': 'Guinobatan',
                          'state': 'Bohol',
                          'postcode': '6324',
                        },
                        'geometry': {
                          'coordinates': [124.3562141, 10.07363],
                        },
                      },
                    ],
            }),
            200,
          );
        }),
      );
      final pin = await service.resolve(
        const MapAddress(street: '', barangay: 'Guinobatan', city: 'Trinidad'),
      );
      expect(pin?.latitude, 10.07363);
      expect(pin?.longitude, 124.3562141);
      expect(pin?.source, 'barangay');
    },
  );
  test(
    'Trinidad auto-pin rejects Talibon and a barangay also named Trinidad',
    () async {
      final service = MapService(
        client: MockClient((request) async {
          expect(request.url.queryParameters['q'], 'Trinidad, Bohol');
          expect(request.url.queryParameters['osm_tag'], 'place');
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'name': 'Talibon',
                    'state': 'Bohol',
                    'osm_value': 'town',
                  },
                  'geometry': {
                    'coordinates': [124.29, 10.15],
                  },
                },
                {
                  'properties': {
                    'name': 'Trinidad',
                    'city': 'Guindulman',
                    'state': 'Bohol',
                    'osm_value': 'village',
                    'type': 'district',
                  },
                  'geometry': {
                    'coordinates': [124.497, 9.77],
                  },
                },
                {
                  'properties': {
                    'name': 'Trinidad',
                    'state': 'Bohol',
                    'osm_value': 'town',
                    'countrycode': 'PH',
                  },
                  'geometry': {
                    'coordinates': [124.3430533, 10.0792217],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      final pin = await service.resolveMunicipality('Trinidad');
      expect(pin?.latitude, 10.0792217);
      expect(pin?.longitude, 124.3430533);
      expect(pin?.source, 'municipality');
      expect(pin?.confirmed, isFalse);
    },
  );

  test(
    'Missing municipality match does not select the first nearby town',
    () async {
      final service = MapService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'name': 'Talibon',
                    'state': 'Bohol',
                    'osm_value': 'town',
                  },
                  'geometry': {
                    'coordinates': [124.29, 10.15],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      expect(await service.resolveMunicipality('Trinidad'), isNull);
    },
  );

  test(
    'A nearby barangay in Talibon cannot replace the Trinidad centre',
    () async {
      final service = MapService(
        client: MockClient((request) async {
          final citySearch =
              request.url.queryParameters['q'] == 'Trinidad, Bohol';
          return http.Response(
            jsonEncode({
              'features': [
                if (citySearch)
                  {
                    'properties': {
                      'name': 'Trinidad',
                      'state': 'Bohol',
                      'osm_value': 'town',
                    },
                    'geometry': {
                      'coordinates': [124.3430533, 10.0792217],
                    },
                  }
                else
                  {
                    'properties': {
                      'name': 'Poblacion',
                      'city': 'Talibon',
                      'state': 'Bohol',
                    },
                    'geometry': {
                      'coordinates': [124.32, 10.1],
                    },
                  },
              ],
            }),
            200,
          );
        }),
      );
      final pin = await service.resolve(
        const MapAddress(street: '', barangay: 'Poblacion', city: 'Trinidad'),
      );
      expect(pin?.source, 'municipality');
      expect(pin?.longitude, 124.3430533);
    },
  );

  test(
    'Reverse geocoding resolves a nearby label, keeps coordinates and caches results',
    () async {
      var requests = 0;
      final service = MapService(
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, '/reverse');
          expect(request.url.queryParameters['lat'], '10.07');
          expect(request.url.queryParameters['lon'], '124.32');
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'name': 'San Vicente',
                    'street': 'Barangay Road',
                    'city': 'Trinidad',
                    'state': 'Bohol',
                    'country': 'Philippines',
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      const pin = GeoPin(10.07, 124.32);
      final label = await service.reverse(pin);
      expect(label, 'San Vicente, Barangay Road, Trinidad, Bohol, Philippines');
      expect(await service.reverse(pin), label);
      expect(requests, 1);
      expect(pin.latitude, 10.07);
    },
  );
  test(
    'Reverse geocoding returns no invented address when no feature is found',
    () async {
      final service = MapService(
        client: MockClient((_) async => http.Response('{"features":[]}', 200)),
      );
      expect(await service.reverse(const GeoPin(10.07, 124.32)), isNull);
    },
  );
  test(
    'Known San Vicente pin is explicitly approximate and needs no network',
    () async {
      final service = MapService(
        client: MockClient((_) async => throw StateError('Unexpected request')),
      );
      final pin = await service.resolve(
        const MapAddress(
          street: 'Purok 1',
          barangay: 'San Vicente',
          city: 'Trinidad',
          barangayCode: '071244017',
        ),
      );
      expect(pin!.source, 'barangay');
      expect(pin.confirmed, isFalse);
      expect(pin.latitude, closeTo(10.0726067, .000001));
    },
  );
  test(
    'OSRM longitude-first inputs and GeoJSON become a road line; repeated routes are cached',
    () async {
      int requests = 0;
      final service = MapService(
        client: MockClient((request) async {
          requests++;
          expect(
            request.url.path,
            contains('124.320000,10.070000;124.340000,10.080000'),
          );
          expect(request.url.queryParameters['geometries'], 'geojson');
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 2000,
                  'duration': 240,
                  'geometry': {
                    'coordinates': [
                      [124.32, 10.07],
                      [124.33, 10.075],
                      [124.34, 10.08],
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      const pins = [GeoPin(10.07, 124.32), GeoPin(10.08, 124.34)];
      final route = await service.route(pins);
      expect(route.geometry.length, 3);
      expect(route.geometry[1].latitude, 10.075);
      expect(route.metres, 2000);
      await service.route(pins);
      expect(requests, 1);
    },
  );
  test(
    'Routing failure never invents a straight-line route and can be retried',
    () async {
      int requests = 0;
      final service = MapService(
        client: MockClient((_) async {
          requests++;
          return http.Response('{"code":"NoRoute","routes":[]}', 200);
        }),
      );
      const pins = [GeoPin(10.07, 124.32), GeoPin(10.08, 124.34)];
      await expectLater(service.route(pins), throwsStateError);
      await expectLater(service.route(pins), throwsStateError);
      expect(requests, 2);
    },
  );
  test('Coordinates received from an embedded map reject malformed values', () {
    expect(GeoPin.fromMessage({'lat': 200, 'lng': 124}), isNull);
    expect(GeoPin.fromMessage({'lat': '10.0', 'lng': 124}), isNull);
    expect(
      GeoPin.fromMessage({'lat': 10.07, 'lng': 124.32})!.confirmed,
      isTrue,
    );
  });
  test(
    'Only the owner can update a pickup pin before collection starts',
    () async {
      final repo = DemoRecyclingRepository();
      const household = AppUser(
        id: 'h1',
        firstname: 'Juan',
        lastname: 'Santos',
        role: UserRole.household,
      );
      const buyer = AppUser(
        id: 'b1',
        firstname: 'Mang',
        lastname: 'Ben',
        role: UserRole.buyer,
      );
      const pin = GeoPin(10.07, 124.32);
      await expectLater(
        repo.updateLocationPin(buyer, 'P102', pin),
        throwsStateError,
      );
      await repo.updateLocationPin(household, 'P102', pin);
      await repo.advancePickup(buyer, 'P102');
      final pickup = (await repo.loadPickups()).firstWhere(
        (pickup) => pickup.id == 'P102',
      );
      expect(pickup.locationPin!.latitude, 10.07);
      expect((pickup.toJson()['location_pin'] as Map)['lng'], 124.32);
      await expectLater(
        repo.updateLocationPin(household, 'P102', pin),
        throwsStateError,
      );
    },
  );
}
