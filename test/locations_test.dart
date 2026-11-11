import 'package:easy_scrap/core/app_config.dart';
import 'package:easy_scrap/core/theme.dart';
import 'package:easy_scrap/data/bohol_locations.dart';
import 'package:easy_scrap/data/demo_auth_repository.dart';
import 'package:easy_scrap/domain/location.dart';
import 'package:easy_scrap/domain/models.dart';
import 'package:easy_scrap/domain/map_location.dart';
import 'package:easy_scrap/domain/registration.dart';
import 'package:easy_scrap/ui/location_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BoholLocations locations;
  setUpAll(() async {
    locations = await BoholLocations.load();
  });
  test(
    'Reverse Guinobatan postal evidence populates Trinidad instead of a namesake town',
    () async {
      final address = ReverseAddress('Guinobatan, Bohol', '', {
        'name': 'Guinobatan',
        'state': 'Bohol',
        'countrycode': 'PH',
        'postcode': '6324',
      });
      final selected = await locations.matchReverseWithPostcode(
        address,
        (name) async => name == 'Trinidad' ? '6324' : '6315',
      );
      expect(selected?.city.name, 'Trinidad');
      expect(selected?.barangay.name, 'Guinobatan');
      final ambiguous = await locations.matchReverseWithPostcode(
        const ReverseAddress('San Vicente, Bohol', '', {
          'name': 'San Vicente',
          'state': 'Bohol',
          'postcode': '6324',
        }),
        (_) async => '6324',
      );
      expect(ambiguous, isNull);
    },
  );
  test(
    'All four national JSON files are available as Flutter assets',
    () async {
      for (final name in [
        'philippine_regions.json',
        'philippine_provinces.json',
        'philippine_cities_municipalities.json',
        'philippine_barangays.json',
      ]) {
        final bytes = await rootBundle.load('assets/data/$name');
        expect(bytes.lengthInBytes, greaterThan(100));
      }
    },
  );
  test('Bohol dataset and city-barangay membership preserve codes', () {
    expect(locations.cities.length, 48);
    expect(
      locations.cities.every((city) => city.parentCode == '071200000'),
      isTrue,
    );
    expect(
      locations.cities.fold<int>(
        0,
        (count, city) => count + locations.barangaysFor(city.code).length,
      ),
      1109,
    );
    final address = locations.selection('071244000', '071244017')!;
    expect(address.city.name, 'Trinidad');
    expect(address.barangay.name, 'San Vicente');
    expect(address.toJson()['barangays'], '071244017');
    expect(locations.selection('071244000', '012801001'), isNull);
    expect(locations.barangaysFor('not-a-city'), isEmpty);
  });
  test(
    'API helper retains version prefix and accepts endpoint query parameters',
    () {
      final url = AppConfig.endpoint(
        '/locations/barangays',
        query: {'cityCode': '071244000'},
      );
      expect(url.path, '/api/v1/locations/barangays');
      expect(url.queryParameters['cityCode'], '071244000');
    },
  );
  test(
    'Registered identity keeps selected city and rejects mismatched barangays',
    () async {
      final city = locations.cities.firstWhere(
        (city) => city.name == 'Alburquerque',
      );
      final barangay = locations.barangaysFor(city.code).first;
      Registration input(String barangayCode) => Registration(
        firstname: 'Ana',
        lastname: 'Reyes',
        contact: '09171234567',
        username: 'ana',
        email: 'ana@example.test',
        password: 'DemoPass123!',
        barangay: barangay.name,
        streetPurok: 'Purok 2',
        role: UserRole.household,
        cityMunicipalityCode: city.code,
        barangayCode: barangayCode,
      );
      final repo = DemoAuthRepository();
      await expectLater(repo.register(input('071244017')), throwsStateError);
      final user = await repo.register(input(barangay.code));
      expect(user.cityMunicipality, 'Alburquerque');
      expect(user.barangayCode, barangay.code);
      expect(user.locationPayload['cities_municipalities'], city.code);
    },
  );
  testWidgets(
    'Changing municipality clears barangay and filters choices by city',
    (tester) async {
      LocationSelection? value;
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: Form(
              key: form,
              child: BoholLocationFields(
                onChanged: (selected) => value = selected,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(value!.barangay.name, 'San Vicente');
      await tester.tap(find.byKey(const Key('location-city')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Alburquerque'),
        -250,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 30,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alburquerque'));
      await tester.pumpAndSettle();
      expect(value, isNull);
      expect(form.currentState!.validate(), isFalse);
      final city = locations.cities.firstWhere(
        (city) => city.name == 'Alburquerque',
      );
      final barangayField = find.byKey(
        ValueKey('location-barangay-${city.code}'),
      );
      final field = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: barangayField,
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(
        field.items!.map((item) => item.value).toSet(),
        locations.barangaysFor(city.code).map((item) => item.code).toSet(),
      );
      await tester.tap(barangayField);
      await tester.pumpAndSettle();
      final first = locations.barangaysFor(city.code).first;
      await tester.ensureVisible(find.text(first.name).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(first.name).last);
      await tester.pumpAndSettle();
      expect(value!.city.code, city.code);
      expect(value!.barangay.code, first.code);
      expect(form.currentState!.validate(), isTrue);
    },
  );
}
