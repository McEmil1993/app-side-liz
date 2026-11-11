import 'package:easy_scrap/application/app_controller.dart';
import 'package:easy_scrap/data/demo_auth_repository.dart';
import 'package:easy_scrap/data/bohol_locations.dart';
import 'package:easy_scrap/data/demo_recycling_repository.dart';
import 'package:easy_scrap/domain/models.dart';
import 'package:easy_scrap/domain/registration.dart';
import 'package:flutter_test/flutter_test.dart';

Registration account({
  String email = 'ana@example.test',
  String username = 'ana_reyes',
  String password = 'DemoPass123!',
  UserRole role = UserRole.household,
}) => Registration(
  firstname: 'Ana',
  lastname: 'Reyes',
  contact: '09171234567',
  username: username,
  email: email,
  password: password,
  barangay: 'Poblacion',
  barangayCode: '071244015',
  streetPurok: 'Purok 3',
  role: role,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await BoholLocations.load();
  });
  test(
    'Seed accounts authenticate by username/email; incorrect password fails',
    () async {
      final repo = DemoAuthRepository();
      expect(
        (await repo.signIn(' HOUSEHOLD ', 'EasyScrap123!')).role,
        UserRole.household,
      );
      expect(
        (await repo.signIn('BUYER@EASYSCRAP.DEMO', 'EasyScrap123!')).role,
        UserRole.buyer,
      );
      await expectLater(
        repo.signIn('household', 'wrong-password'),
        throwsStateError,
      );
    },
  );
  test(
    'Registration keeps identity and role; rejects duplicate email/username',
    () async {
      final repo = DemoAuthRepository();
      final user = await repo.register(account(role: UserRole.buyer));
      expect(user.id, isNot(anyOf('h1', 'b1')));
      expect(user.buyerVerified, isFalse);
      expect(user.barangay, 'Poblacion');
      expect((await repo.signIn('ana_reyes', 'DemoPass123!')).id, user.id);
      await expectLater(
        repo.register(account(email: 'ANA@EXAMPLE.TEST', username: 'new_name')),
        throwsStateError,
      );
      await expectLater(
        repo.register(
          account(email: 'other@example.test', username: 'ANA_REYES'),
        ),
        throwsStateError,
      );
      await expectLater(
        repo.register(account(email: 'invalid', username: 'other')),
        throwsStateError,
      );
      await expectLater(
        repo.register(
          account(
            email: 'other@example.test',
            username: 'other',
            password: 'short',
          ),
        ),
        throwsStateError,
      );
    },
  );
  test(
    'Logout clears session but allows registered account to log in again',
    () async {
      final app = AppController(DemoRecyclingRepository());
      await app.refresh();
      await app.register(account());
      final id = app.user.id;
      expect(app.ownPickups, isEmpty);
      app.signOut();
      expect(app.role, isNull);
      expect(() => app.user, throwsStateError);
      await app.signIn('ana@example.test', 'DemoPass123!');
      expect(app.user.id, id);
      app.dispose();
    },
  );
}
