import 'models.dart';
import 'location.dart';

class Registration {
  final String firstname, middlename, lastname, suffix, contact;
  final String username, email, password, barangay, streetPurok;
  final UserRole role;
  final String cityMunicipalityCode, barangayCode;
  const Registration({
    required this.firstname,
    this.middlename = '',
    required this.lastname,
    this.suffix = '',
    required this.contact,
    required this.username,
    required this.email,
    required this.password,
    required this.barangay,
    required this.streetPurok,
    required this.role,
    this.cityMunicipalityCode = LocationDefaults.cityCode,
    this.barangayCode = LocationDefaults.barangayCode,
  });
}

abstract final class AccountValidation {
  static String? requiredName(String? value) =>
      (value ?? '').trim().isEmpty ? 'This field is required.' : null;
  static String? email(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((value ?? '').trim())
      ? null
      : 'Enter a valid email address.';
  static String? username(String? value) =>
      RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch((value ?? '').trim())
      ? null
      : 'Use 3–30 letters, numbers or underscores.';
  static String? contact(String? value) =>
      RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch((value ?? '').trim())
      ? null
      : 'Use 09XXXXXXXXX or +639XXXXXXXXX.';
  static String? password(String? value) =>
      (value ?? '').length >= 8 && (value ?? '').length <= 72
      ? null
      : 'Use 8–72 characters.';
}
