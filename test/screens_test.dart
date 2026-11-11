import 'package:easy_scrap/application/app_controller.dart';
import 'package:easy_scrap/data/demo_recycling_repository.dart';
import 'package:easy_scrap/data/bohol_locations.dart';
import 'package:easy_scrap/domain/models.dart';
import 'package:easy_scrap/ui/app.dart';
import 'package:easy_scrap/ui/collection_screen.dart';
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
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
    await icons.load();
  });
  for (final sample in [
    (
      name: 'household-home',
      role: UserRole.household,
      tab: 0,
      detail: false,
      collection: false,
    ),
    (
      name: 'household-post',
      role: UserRole.household,
      tab: 2,
      detail: false,
      collection: false,
    ),
    (
      name: 'household-accepted',
      role: UserRole.household,
      tab: 0,
      detail: true,
      collection: false,
    ),
    (
      name: 'buyer-marketplace',
      role: UserRole.buyer,
      tab: 0,
      detail: false,
      collection: false,
    ),
    (
      name: 'buyer-route',
      role: UserRole.buyer,
      tab: 1,
      detail: false,
      collection: false,
    ),
    (
      name: 'buyer-collection',
      role: UserRole.buyer,
      tab: 0,
      detail: false,
      collection: true,
    ),
  ]) {
    testWidgets('${sample.name} phone layout', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = DemoRecyclingRepository(now: DateTime(2026, 10, 15));
      final app = AppController(repo, clock: () => DateTime(2026, 10, 15));
      await app.refresh();
      await app.signIn(
        sample.role == UserRole.household ? 'household' : 'buyer',
        'EasyScrap123!',
      );
      if (sample.collection) {
        await app.advance('P102');
        await app.advance('P102');
      }
      await tester.pumpWidget(EasyScrapApp(controller: app));
      if (sample.tab != 0) {
        await tester.tap(find.byType(NavigationDestination).at(sample.tab));
      }
      await tester.pumpAndSettle();
      if (sample.detail || sample.collection) {
        final context = tester.element(find.byType(MobileShell));
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => sample.detail
                ? const PickupDetailScreen(pickupId: 'P102')
                : const CollectionScreen(pickupId: 'P102'),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/previews/${sample.name}.png'),
      );
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  }
}
