import 'package:easy_scrap/application/app_controller.dart';
import 'package:easy_scrap/data/demo_recycling_repository.dart';
import 'package:easy_scrap/data/bohol_locations.dart';
import 'package:easy_scrap/domain/models.dart';
import 'package:easy_scrap/domain/map_location.dart';
import 'package:easy_scrap/ui/app.dart';
import 'package:easy_scrap/ui/maps/address_map.dart';
import 'package:easy_scrap/ui/pickup_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await BoholLocations.load();
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    await font.load();
  });
  Future<void> login(WidgetTester tester, String username) async {
    await tester.enterText(find.byKey(const Key('login-identifier')), username);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('login-password')),
        matching: find.byType(TextFormField),
      ),
      'EasyScrap123!',
    );
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('Household can inspect a buyer offer without selecting it', (
    tester,
  ) async {
    final app = AppController(DemoRecyclingRepository());
    await app.refresh();
    await app.signIn('household', 'EasyScrap123!');
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      EasyScrapApp(controller: app, navigatorKey: navigator),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const PickupDetailScreen(pickupId: 'P101'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Mang Ben'), 200);
    await tester.tap(find.text('Mang Ben'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('LGU verified buyer'), findsOneWidget);
    expect(find.text('Location: Not provided'), findsOneWidget);
    expect(app.pickup('P101').status, PickupStatus.open);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Log in, visit every tab, log out and log in as buyer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppController(DemoRecyclingRepository());
    await app.refresh();
    await tester.pumpWidget(EasyScrapApp(controller: app));
    await login(tester, 'household');
    expect(app.role, UserRole.household);
    for (var tab = 0; tab < 5; tab++) {
      await tester.tap(find.byType(NavigationDestination).at(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.scrollUntilVisible(
      find.text('Log out'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(app.currentUser, isNull);
    await login(tester, 'buyer');
    expect(app.role, UserRole.buyer);
    for (var tab = 0; tab < 5; tab++) {
      await tester.tap(find.byType(NavigationDestination).at(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets(
    'Post hides the pickup map by default, can expand it, and publishes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppController(DemoRecyclingRepository());
      await app.refresh();
      await app.signIn('household', 'EasyScrap123!');
      await tester.pumpWidget(EasyScrapApp(controller: app));
      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      final before = app.ownPickups.length;
      expect(find.byType(AddressMap), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'GoogleMapView',
        ),
        findsNothing,
      );
      final toggle = find
          .descendant(
            of: find.byKey(const Key('post-pickup-map')),
            matching: find.byType(IconButton),
          )
          .first;
      await tester.scrollUntilVisible(
        toggle,
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byType(AddressMap), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'GoogleMapView',
        ),
        findsOneWidget,
      );
      final locations = await BoholLocations.load();
      final city = locations.cities.firstWhere((c) => c.name == 'Talibon');
      final selected = locations.selection(
        city.code,
        locations.barangaysFor(city.code).first.code,
      )!;
      final confirmed = GeoPin(
        10.1,
        124.3,
        location: selected,
        label: '${selected.barangay.name}, Talibon, Bohol',
      );
      tester.widget<AddressMap>(find.byType(AddressMap)).onSave!(confirmed);
      await tester.pumpAndSettle();
      final updatedMap = tester.widget<AddressMap>(find.byType(AddressMap));
      expect(updatedMap.address.city, 'Talibon');
      expect(updatedMap.address.barangayCode, selected.barangay.code);
      expect(updatedMap.address.street, isEmpty);
      expect(updatedMap.savedPin, same(confirmed));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byType(AddressMap), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'GoogleMapView',
        ),
        findsNothing,
      );
      final weight = find.byKey(const Key('post-estimated-weight'));
      await tester.scrollUntilVisible(
        weight,
        -250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(weight, '7.5');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(FilledButton, 'Publish request');
      await tester.scrollUntilVisible(
        submit,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(app.ownPickups.length, before + 1);
      expect(app.ownPickups.first.estimatedKg, 7.5);
      expect(app.ownPickups.first.cityMunicipality, 'Talibon');
      expect(app.ownPickups.first.barangayCode, selected.barangay.code);
      expect(app.ownPickups.first.streetPurok, isEmpty);
      expect(app.ownPickups.first.locationPin, same(confirmed));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
}
