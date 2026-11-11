import 'package:easy_scrap/application/app_controller.dart';
import 'package:easy_scrap/data/demo_recycling_repository.dart';
import 'package:easy_scrap/data/bohol_locations.dart';
import 'package:easy_scrap/domain/models.dart';
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
  Future<AppController> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppController(DemoRecyclingRepository());
    await app.refresh();
    await tester.pumpWidget(EasyScrapApp(controller: app));
    await tester.pumpAndSettle();
    return app;
  }

  Finder input(String key) {
    final widget = find.byKey(Key(key));
    return key.endsWith('password') || key.endsWith('confirmation')
        ? find.descendant(of: widget, matching: find.byType(TextFormField))
        : widget;
  }

  Future<void> fill(WidgetTester tester, String key, String value) async {
    await tester.ensureVisible(input(key));
    await tester.pumpAndSettle();
    await tester.enterText(input(key), value);
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder button) async {
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Invalid login stays logged out; valid buyer enters buyer navigation',
    (tester) async {
      final app = await open(tester);
      await fill(tester, 'login-identifier', 'buyer');
      await fill(tester, 'login-password', 'incorrect');
      await press(tester, find.byKey(const Key('login-submit')));
      expect(app.currentUser, isNull);
      expect(
        find.text('Incorrect email/username or password. Please try again.'),
        findsOneWidget,
      );
      await fill(tester, 'login-password', 'EasyScrap123!');
      await press(tester, find.byKey(const Key('login-submit')));
      expect(app.role, UserRole.buyer);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
  testWidgets(
    'Registration validates confirmation then uses the new household identity',
    (tester) async {
      final app = await open(tester);
      await press(tester, find.text('New here? Create an account'));
      for (final field in {
        'register-first': 'Ana',
        'register-last': 'Reyes',
        'register-contact': '09171234567',
        'register-street': 'Purok 4',
        'register-username': 'ana_reyes',
        'register-email': 'ana@example.test',
        'register-password': 'MyDemoPass123!',
        'register-confirmation': 'DifferentPass123!',
      }.entries) {
        await fill(tester, field.key, field.value);
      }
      await press(tester, find.byKey(const Key('register-submit')));
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(app.currentUser, isNull);
      await fill(tester, 'register-confirmation', 'MyDemoPass123!');
      await press(tester, find.byKey(const Key('register-submit')));
      expect(app.user.name, 'Ana Reyes');
      expect(app.role, UserRole.household);
      expect(app.ownPickups, isEmpty);
      expect(find.text('Magandang araw, Ana!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
  for (final register in [false, true]) {
    testWidgets('${register ? 'register' : 'login'} phone preview', (
      tester,
    ) async {
      final app = await open(tester);
      if (register) {
        await press(tester, find.text('New here? Create an account'));
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../docs/previews/${register ? 'register' : 'login'}.png',
        ),
      );
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  }
}
