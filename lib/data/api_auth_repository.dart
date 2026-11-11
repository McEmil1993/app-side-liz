import 'dart:convert';
import '../domain/models.dart';
import '../domain/map_location.dart';
import '../domain/registration.dart';
import 'api_client.dart';
import 'auth_repository.dart';

AppUser userFromApi(Map<String, dynamic> value) {
  final names = (value['location_names'] as Map?) ?? {};
  final uri = value['avatar_data_uri'] as String?;
  return AppUser(
    id: '${value['id']}',
    firstname: value['firstname'] as String,
    lastname: value['lastname'] as String,
    role: value['role'] == 'buyer' ? UserRole.buyer : UserRole.household,
    middlename: value['middlename'] as String? ?? '',
    suffix: value['suffix'] as String? ?? '',
    username: value['username'] as String,
    email: value['email'] as String,
    contact: value['contact'] as String,
    streetPurok: value['street_purok'] as String,
    cityMunicipality: '${names['cities_municipalities'] ?? ''}',
    barangay: '${names['barangays'] ?? ''}',
    cityMunicipalityCode: value['cities_municipalities'] as String,
    barangayCode: value['barangays'] as String,
    buyerVerified: value['buyer_verified'] == true,
    verificationStatus: '${value['verification_status'] ?? 'not_submitted'}',
    avatar: uri == null ? null : base64Decode(uri.split(',').last),
  );
}

class ApiAuthRepository implements AccountRepository {
  final ApiClient client;
  @override
  GeoPin? profilePin;
  ApiAuthRepository(this.client);
  AppUser _user(dynamic data) {
    final value = Map<String, dynamic>.from(data as Map);
    final pin = value['location_pin'] as Map?;
    profilePin = pin == null
        ? null
        : GeoPin(
            (pin['lat'] as num).toDouble(),
            (pin['lng'] as num).toDouble(),
            source: '${pin['source'] ?? 'manual'}',
            label: '${pin['label'] ?? ''}',
          );
    return userFromApi(value);
  }

  Future<AppUser> _session(String path, Map<String, Object?> body) async {
    final result =
        await client.request(path, method: 'POST', body: body) as Map;
    await client.setToken(result['token'] as String);
    return _user(result['user']);
  }

  @override
  Future<AppUser> signIn(String identifier, String password) => _session(
    'auth/login',
    {'identifier': identifier.trim(), 'password': password},
  );
  @override
  Future<AppUser> register(Registration input) => _session('auth/register', {
    'firstname': input.firstname,
    'middlename': input.middlename.isEmpty ? null : input.middlename,
    'lastname': input.lastname,
    'suffix': input.suffix.isEmpty ? null : input.suffix,
    'contact': input.contact,
    'regions': '070000000',
    'provinces': '071200000',
    'cities_municipalities': input.cityMunicipalityCode,
    'barangays': input.barangayCode,
    'street_purok': input.streetPurok,
    'username': input.username,
    'email': input.email,
    'password': input.password,
    'role': input.role.name,
  });
  @override
  Future<AppUser?> restoreSession() async {
    await client.restore();
    if (client.token == null) return null;
    try {
      return await loadProfile();
    } on ApiException catch (error) {
      if (error.status == 401) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (client.token != null) {
        await client.request('auth/logout', method: 'POST');
      }
    } finally {
      await client.clearToken();
      profilePin = null;
    }
  }

  @override
  Future<AppUser> loadProfile() async => _user(await client.request('me'));
  @override
  Future<AppUser> updateProfile(Map<String, Object?> values) async =>
      _user(await client.request('me', method: 'PUT', body: values));
  @override
  Future<AppUser> updateAvatar(String dataUri) async => _user(
    await client.request(
      'me/avatar',
      method: 'PUT',
      body: {'data_uri': dataUri},
    ),
  );
  @override
  Future<AppUser> savePin(AppUser user, GeoPin pin) async => _user(
    await client.request(
      'me/pin',
      method: 'PUT',
      body: {
        'location_pin': {
          'lat': pin.latitude,
          'lng': pin.longitude,
          'source': pin.source,
          'label': pin.label,
        },
        'profile': {...user.locationPayload, 'street_purok': user.streetPurok},
      },
    ),
  );
  @override
  Future<void> changePassword(String current, String password) async {
    await client.request(
      'me/password',
      method: 'PUT',
      body: {'currentPassword': current, 'newPassword': password},
    );
    await client.clearToken();
  }

  @override
  Future<Map<String, dynamic>?> verification() async {
    final result = await client.request('verification');
    return result == null ? null : Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<Map<String, dynamic>> verificationDocument(String id) async =>
      Map<String, dynamic>.from(
        await client.request('verification/documents/$id') as Map,
      );

  @override
  Future<void> submitVerification(
    String shop,
    List<Map<String, String>> documents,
  ) async {
    await client.request(
      'verification',
      method: 'POST',
      body: {'shop_name': shop, 'documents': documents},
    );
  }
}
