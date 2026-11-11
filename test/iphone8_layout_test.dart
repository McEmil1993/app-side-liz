import 'package:easy_scrap/application/app_controller.dart';
import 'package:easy_scrap/data/bohol_locations.dart';
import 'package:easy_scrap/data/demo_recycling_repository.dart';
import 'package:easy_scrap/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await BoholLocations.load();
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final username in ['household', 'buyer']) {
    testWidgets('$username tabs fit the iPhone 8 viewport', (tester) async {
      // iPhone 8: 750 x 1334 physical pixels, 375 x 667 logical points.
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      tester.view.padding = const FakeViewPadding(top: 40);
      addTearDown(tester.view.reset);

      final app = AppController(DemoRecyclingRepository());
      await app.refresh();
      await tester.pumpWidget(EasyScrapApp(controller: app));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Login layout');

      await app.signIn(username, 'EasyScrap123!');
      await tester.pumpAndSettle();
      for (var tab = 0; tab < 5; tab++) {
        final destination = find.byType(NavigationDestination).at(tab);
        expect(destination.hitTestable(), findsOneWidget);
        await tester.tap(destination);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$username tab $tab');
      }
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  }
}
