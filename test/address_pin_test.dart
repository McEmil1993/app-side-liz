import 'dart:convert';
import 'package:easy_scrap/data/bohol_locations.dart';
import 'package:easy_scrap/data/map_service.dart';
import 'package:easy_scrap/domain/map_location.dart';
import 'package:easy_scrap/ui/location_fields.dart';
import 'package:easy_scrap/ui/maps/address_map.dart';
import 'package:easy_scrap/ui/maps/google_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BoholLocations locations;
  setUpAll(() async {
    locations = await BoholLocations.load();
  });
  testWidgets(
    'A tapped pin populates barangay/town; correcting its address preserves the chosen coordinates',
    (tester) async {
      final service = MapService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'name': 'Guinobatan',
                    'city': 'Trinidad',
                    'state': 'Bohol',
                    'countrycode': 'PH',
                  },
                  'geometry': {
                    'coordinates': [124.3562, 10.0736],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      GeoPin? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AddressMap(
                address: const MapAddress(
                  street: '',
                  barangay: 'San Vicente',
                  city: 'Trinidad',
                ),
                savedPin: const GeoPin(10.079, 124.343),
                service: service,
                onSave: (pin) {
                  saved = pin;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Show map'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set pin'));
      await tester.pumpAndSettle();
      tester.widget<GoogleMapView>(find.byType(GoogleMapView)).onMessage({
        'type': 'pin',
        'lat': 10.07361,
        'lng': 124.35622,
      });
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      var fields = tester.widget<BoholLocationFields>(
        find.byType(BoholLocationFields),
      );
      final guino = locations
          .barangaysFor('071244000')
          .firstWhere((b) => b.name == 'Guinobatan');
      expect(fields.initialCityCode, '071244000');
      expect(fields.initialBarangayCode, guino.code);
      expect(find.textContaining('10.073610, 124.356220'), findsOneWidget);
      final correction = locations.selection('071244000', '071244017')!;
      fields.onChanged(correction);
      fields.onBarangaySelected!(correction);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save pin & address');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved?.latitude, 10.07361);
      expect(saved?.longitude, 124.35622);
      expect(saved?.location?.barangay.name, 'San Vicente');
      expect(saved?.location?.city.name, 'Trinidad');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
