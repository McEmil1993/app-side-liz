import '../domain/models.dart';
import '../domain/registration.dart';
import 'auth_repository.dart';
import 'bohol_locations.dart';

/// Demo credentials exist only in memory. Never use this as production auth.
class DemoAuthRepository implements AuthRepository {
  static const password = 'EasyScrap123!';
  final List<({AppUser user, String password})> _accounts = [
    (
      user: const AppUser(
        id: 'h1',
        firstname: 'Juan',
        lastname: 'Santos',
        role: UserRole.household,
        username: 'household',
        email: 'household@easyscrap.demo',
        contact: '09170000001',
        streetPurok: 'Purok 1',
      ),
      password: password,
    ),
    (
      user: const AppUser(
        id: 'b1',
        firstname: 'Mang',
        lastname: 'Ben',
        role: UserRole.buyer,
        username: 'buyer',
        email: 'buyer@easyscrap.demo',
        contact: '09170000002',
        streetPurok: 'Purok 1',
        buyerVerified: true,
      ),
      password: password,
    ),
  ];
  int _nextId = 1;

  @override
  Future<AppUser> signIn(String identifier, String password) async {
    final key = identifier.trim().toLowerCase();
    for (final account in _accounts) {
      if ((account.user.email.toLowerCase() == key ||
              account.user.username.toLowerCase() == key) &&
          account.password == password) {
        return account.user;
      }
    }
    throw StateError('Incorrect email/username or password. Please try again.');
  }

  @override
  Future<AppUser> register(Registration input) async {
    final errors = [
      AccountValidation.requiredName(input.firstname),
      AccountValidation.requiredName(input.lastname),
      AccountValidation.contact(input.contact),
      AccountValidation.email(input.email),
      AccountValidation.username(input.username),
      AccountValidation.password(input.password),
      AccountValidation.requiredName(input.barangay),
      AccountValidation.requiredName(input.streetPurok),
    ];
    if (errors.any((error) => error != null)) {
      throw StateError(errors.firstWhere((error) => error != null)!);
    }
    final locations = await BoholLocations.load();
    final selected = locations.selection(
      input.cityMunicipalityCode,
      input.barangayCode,
    );
    if (selected == null) {
      throw StateError(
        'Choose a Bohol city / municipality and a barangay belonging to it.',
      );
    }
    final email = input.email.trim().toLowerCase();
    final username = input.username.trim();
    if (_accounts.any((account) => account.user.email.toLowerCase() == email)) {
      throw StateError('This email address is already registered.');
    }
    if (_accounts.any(
      (account) =>
          account.user.username.toLowerCase() == username.toLowerCase(),
    )) {
      throw StateError('This username is already taken.');
    }
    final user = AppUser(
      id: 'demo-user-${_nextId++}',
      firstname: input.firstname.trim(),
      middlename: input.middlename.trim(),
      lastname: input.lastname.trim(),
      suffix: input.suffix.trim(),
      role: input.role,
      contact: input.contact.trim(),
      username: username,
      email: email,
      barangay: selected.barangay.name,
      cityMunicipality: selected.city.name,
      cityMunicipalityCode: selected.city.code,
      barangayCode: selected.barangay.code,
      streetPurok: input.streetPurok.trim(),
    );
    _accounts.add((user: user, password: input.password));
    return user;
  }
}
