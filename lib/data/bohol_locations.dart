import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/location.dart';
import '../domain/map_location.dart';

/// Reads the four Philippine JSON snapshots bundled inside this Flutter app.
class BoholLocations {
  final List<LocationOption> cities;
  final Map<String, List<LocationOption>> _barangays;
  BoholLocations._(this.cities, this._barangays);
  static Future<BoholLocations>? _cached;
  static BoholLocations? _loaded;
  static Future<BoholLocations> load() => _loaded != null
      ? Future.value(_loaded!)
      : _cached ??= _read().catchError((Object error) {
          _cached = null;
          throw error;
        });
  static Future<BoholLocations> _read() async {
    final files = await Future.wait(
      [
        'philippine_regions.json',
        'philippine_provinces.json',
        'philippine_cities_municipalities.json',
        'philippine_barangays.json',
      ].map((name) => rootBundle.loadString('assets/data/$name')),
    );
    final regions = jsonDecode(files[0]) as List;
    final provinces = jsonDecode(files[1]) as List;
    if (!regions.any((item) => item['code'] == LocationDefaults.regionCode) ||
        !provinces.any(
          (item) =>
              item['code'] == LocationDefaults.provinceCode &&
              item['regionCode'] == LocationDefaults.regionCode,
        )) {
      throw StateError(
        'The bundled Region VII / Bohol location data is missing.',
      );
    }
    final cities =
        (jsonDecode(files[2]) as List)
            .where(
              (item) => item['provinceCode'] == LocationDefaults.provinceCode,
            )
            .map(
              (item) => LocationOption(
                code: item['code'] as String,
                name: item['name'] as String,
                parentCode: item['provinceCode'] as String,
              ),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final groups = <String, List<LocationOption>>{};
    final cityCodes = cities.map((city) => city.code).toSet();
    for (final item in jsonDecode(files[3]) as List) {
      final parent = item['cityCode'] == false || item['cityCode'] == null
          ? item['municipalityCode']
          : item['cityCode'];
      if (item['provinceCode'] != LocationDefaults.provinceCode ||
          !cityCodes.contains(parent)) {
        continue;
      }
      final barangay = LocationOption(
        code: item['code'] as String,
        name: item['name'] as String,
        parentCode: parent as String,
      );
      groups.putIfAbsent(barangay.parentCode, () => []).add(barangay);
    }
    return _loaded = BoholLocations._(List.unmodifiable(cities), {
      for (final entry in groups.entries)
        entry.key: List.unmodifiable(
          entry.value..sort((a, b) => a.name.compareTo(b.name)),
        ),
    });
  }

  /// Never choose an arbitrary municipality for a shared barangay name.
  LocationSelection? matchReverse(
    ReverseAddress address, {
    Map<String, String> municipalityPostcodes = const {},
  }) {
    String normal(String value) => value
        .toLowerCase()
        .replaceAll(
          RegExp(r'^(barangay|brgy\.?|municipality of|city of)\s+'),
          '',
        )
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final p = address.properties;
    final country = '${p['countrycode'] ?? ''}'.toLowerCase();
    if (country.isNotEmpty && country != 'ph') return null;
    final state = '${p['state'] ?? ''}';
    if (state.isNotEmpty && normal(state) != 'bohol') return null;
    final cityNames = [
      p['city'],
      p['county'],
      p['name'],
    ].whereType<String>().map(normal).toSet();
    final matchedCities = cities
        .where(
          (c) =>
              cityNames.contains(normal(c.name)) ||
              municipalityPostcodes[c.code] != null &&
                  municipalityPostcodes[c.code] == p['postcode']?.toString(),
        )
        .toList();
    final barangayNames = [
      p['district'],
      p['locality'],
      p['name'],
      p['city'],
    ].whereType<String>().map(normal).toSet();
    final candidates = <LocationSelection>[];
    for (final city in matchedCities.isEmpty ? cities : matchedCities) {
      for (final barangay in barangaysFor(city.code)) {
        if (barangayNames.contains(normal(barangay.name))) {
          candidates.add(LocationSelection(city: city, barangay: barangay));
        }
      }
    }
    return candidates.length == 1 ? candidates.single : null;
  }

  /// Resolve ambiguous barangay names using provider postal evidence, never
  /// just the selected profile address or the closest municipality centre.
  Future<LocationSelection?> matchReverseWithPostcode(
    ReverseAddress address,
    Future<String?> Function(String) postcodeForCity,
  ) async {
    final direct = matchReverse(address);
    if (direct != null) return direct;
    if ('${address.properties['postcode'] ?? ''}'.isEmpty) return null;
    final names = [
      'district',
      'locality',
      'name',
      'city',
    ].map((k) => '${address.properties[k] ?? ''}'.toLowerCase().trim()).toSet();
    final candidates = cities
        .where(
          (city) => barangaysFor(
            city.code,
          ).any((b) => names.contains(b.name.toLowerCase().trim())),
        )
        .toList();
    if (candidates.isEmpty || candidates.length > 5) return null;
    final codes = <String, String>{};
    for (final city in candidates) {
      final postcode = await postcodeForCity(city.name);
      if (postcode != null) codes[city.code] = postcode;
    }
    final matching = codes.entries
        .where((e) => e.value == address.properties['postcode']?.toString())
        .toList();
    if (matching.length != 1) return null;
    return matchReverse(
      address,
      municipalityPostcodes: {matching.single.key: matching.single.value},
    );
  }

  List<LocationOption> barangaysFor(String? cityCode) =>
      _barangays[cityCode] ?? const [];
  LocationSelection? selection(String? cityCode, String? barangayCode) {
    final citiesFound = cities.where((city) => city.code == cityCode);
    final barangaysFound = barangaysFor(
      cityCode,
    ).where((barangay) => barangay.code == barangayCode);
    if (citiesFound.isEmpty || barangaysFound.isEmpty) return null;
    return LocationSelection(
      city: citiesFound.first,
      barangay: barangaysFound.first,
    );
  }
}
