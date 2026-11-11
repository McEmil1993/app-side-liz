import '../domain/models.dart';
import '../domain/registration.dart';
import '../domain/map_location.dart';

/// Replace with a server-backed implementation when authentication is ready.
abstract interface class AuthRepository {
  Future<AppUser> signIn(String identifier, String password);
  Future<AppUser> register(Registration registration);
}

abstract interface class AccountRepository implements AuthRepository {
  Future<AppUser?> restoreSession();
  Future<void> signOut();
  Future<AppUser> loadProfile();
  GeoPin? get profilePin;
  Future<AppUser> updateProfile(Map<String, Object?> values);
  Future<AppUser> updateAvatar(String dataUri);
  Future<AppUser> savePin(AppUser user, GeoPin pin);
  Future<void> changePassword(String current, String password);
  Future<Map<String, dynamic>?> verification();
  Future<Map<String, dynamic>> verificationDocument(String id);
  Future<void> submitVerification(
    String shop,
    List<Map<String, String>> documents,
  );
}
