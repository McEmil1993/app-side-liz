import 'package:easy_scrap/application/app_controller.dart';
import 'package:easy_scrap/data/bohol_locations.dart';
import 'package:easy_scrap/data/demo_recycling_repository.dart';
import 'package:easy_scrap/domain/map_location.dart';
import 'package:easy_scrap/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BoholLocations locations;
  setUpAll(() async => locations = await BoholLocations.load());

  test('Reverse components match barangay codes only when unambiguous', () {
    final selection = locations.matchReverse(
      const ReverseAddress('', '', {
        'district': 'San Vicente',
        'city': 'Trinidad',
        'state': 'Bohol',
        'countrycode': 'PH',
      }),
    );
    expect(selection?.barangay.code, '071244017');
    // San Vicente is shared by multiple municipalities. Never pick the first.
    expect(
      locations.matchReverse(
        const ReverseAddress('', '', {'name': 'San Vicente', 'state': 'Bohol'}),
      ),
      isNull,
    );
    expect(
      locations.matchReverse(
        const ReverseAddress('', '', {
          'district': 'San Vicente',
          'city': 'Trinidad',
          'state': 'Cebu',
        }),
      ),
      isNull,
    );
    expect(
      locations.matchReverse(
        const ReverseAddress('', '', {
          'name': 'Unknown landmark',
          'city': 'Trinidad',
          'state': 'Bohol',
        }),
      ),
      isNull,
    );
  });

  test(
    'Profile saves coordinates and address together and retains them on login',
    () async {
      final app = AppController(DemoRecyclingRepository());
      await app.signIn('household', 'EasyScrap123!');
      final targetCity = locations.cities.firstWhere(
        (c) => c.name == 'Talibon',
      );
      final target = locations.selection(
        targetCity.code,
        locations.barangaysFor(targetCity.code).first.code,
      )!;
      final pin = GeoPin(10.1, 124.3, location: target);
      app.saveProfilePin(pin);
      expect(app.user.cityMunicipality, 'Talibon');
      expect(app.user.barangay, target.barangay.name);
      expect(app.user.locationPayload['barangays'], target.barangay.code);
      expect(app.user.streetPurok, isEmpty); // The old Purok 1 is not reused.
      app.signOut();
      await app.signIn('household', 'EasyScrap123!');
      expect(app.user.cityMunicipalityCode, targetCity.code);
      expect(app.profilePin, same(pin));
      app.signOut();
      await app.signIn('buyer', 'EasyScrap123!');
      expect(app.user.cityMunicipality, 'Trinidad');
      expect(app.profilePin, isNull);
      app.dispose();
    },
  );

  test(
    'Pickup pin changes address and serialized codes only for that pickup',
    () async {
      final repo = DemoRecyclingRepository();
      const household = AppUser(
        id: 'h1',
        firstname: 'Juan',
        lastname: 'Santos',
        role: UserRole.household,
      );
      final city = locations.cities.firstWhere((c) => c.name == 'Talibon');
      final selected = locations.selection(
        city.code,
        locations.barangaysFor(city.code).first.code,
      )!;
      final before = await repo.loadPickups();
      await repo.updateLocationPin(
        household,
        'P102',
        GeoPin(10.1, 124.3, location: selected),
      );
      final after = await repo.loadPickups();
      final updated = after.firstWhere((p) => p.id == 'P102');
      expect(updated.cityMunicipality, 'Talibon');
      expect(updated.streetPurok, isEmpty);
      expect(updated.toJson()['barangays'], selected.barangay.code);
      for (final old in before.where((p) => p.id != 'P102')) {
        expect(after.firstWhere((p) => p.id == old.id), same(old));
      }
      expect(household.cityMunicipality, 'Trinidad');
    },
  );
}
