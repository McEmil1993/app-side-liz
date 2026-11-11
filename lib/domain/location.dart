abstract final class LocationDefaults {
  static const regionCode = '070000000';
  static const provinceCode = '071200000';
  static const cityCode = '071244000';
  static const barangayCode = '071244017';
}

class LocationOption {
  final String code, name, parentCode;
  const LocationOption({
    required this.code,
    required this.name,
    required this.parentCode,
  });
  factory LocationOption.fromJson(Map<String, dynamic> json) => LocationOption(
    code: json['code'] as String,
    name: json['name'] as String,
    parentCode: json['parentCode'] as String,
  );
}

class LocationSelection {
  final LocationOption city, barangay;
  const LocationSelection({required this.city, required this.barangay});
  Map<String, String> toJson() => {
    'regions': LocationDefaults.regionCode,
    'provinces': LocationDefaults.provinceCode,
    'cities_municipalities': city.code,
    'barangays': barangay.code,
  };
}
