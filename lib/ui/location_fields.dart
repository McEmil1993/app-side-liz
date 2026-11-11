import 'package:flutter/material.dart';
import '../data/bohol_locations.dart';
import '../domain/location.dart';
import '../core/theme.dart';

/// Codes are values; dropdowns display names only. Changing a city clears its barangay.
class BoholLocationFields extends StatefulWidget {
  final String initialCityCode, initialBarangayCode;
  final ValueChanged<LocationSelection?> onChanged;
  final ValueChanged<LocationOption>? onCityChanged;
  final ValueChanged<LocationSelection>? onBarangaySelected;
  const BoholLocationFields({
    super.key,
    this.initialCityCode = LocationDefaults.cityCode,
    this.initialBarangayCode = LocationDefaults.barangayCode,
    required this.onChanged,
    this.onCityChanged,
    this.onBarangaySelected,
  });
  @override
  State<BoholLocationFields> createState() => _BoholLocationFieldsState();
}

class _BoholLocationFieldsState extends State<BoholLocationFields> {
  BoholLocations? data;
  String? cityCode, barangayCode;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await BoholLocations.load();
      if (!mounted) return;
      final valid = loaded.selection(
        widget.initialCityCode,
        widget.initialBarangayCode,
      );
      setState(() {
        data = loaded;
        failed = false;
        cityCode = loaded.cities.any((c) => c.code == widget.initialCityCode)
            ? widget.initialCityCode
            : null;
        barangayCode = valid?.barangay.code;
      });
      widget.onChanged(valid);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: failed
            ? TextButton.icon(
                onPressed: () {
                  setState(() => failed = false);
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry loading locations'),
              )
            : const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Loading locations…',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
      );
    }
    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: const Key('location-city'),
          initialValue: cityCode,
          isExpanded: true,
          menuMaxHeight: 320,
          decoration: const InputDecoration(
            labelText: 'City / Municipality',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          items: data!.cities
              .map(
                (city) => DropdownMenuItem(
                  value: city.code,
                  child: Text(city.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          validator: (value) =>
              value == null ? 'Choose a city / municipality.' : null,
          onChanged: (value) {
            setState(() {
              cityCode = value;
              barangayCode = null;
            });
            widget.onChanged(null);
            if (value != null) {
              widget.onCityChanged?.call(
                data!.cities.firstWhere((c) => c.code == value),
              );
            }
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('location-barangay-$cityCode'),
          initialValue: barangayCode,
          isExpanded: true,
          menuMaxHeight: 320,
          decoration: const InputDecoration(
            labelText: 'Barangay',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          hint: const Text('Choose a barangay'),
          items: data!
              .barangaysFor(cityCode)
              .map(
                (barangay) => DropdownMenuItem(
                  value: barangay.code,
                  child: Text(barangay.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          validator: (value) => value == null ? 'Choose a barangay.' : null,
          onChanged: cityCode == null
              ? null
              : (value) {
                  setState(() => barangayCode = value);
                  final selected = data!.selection(cityCode, value);
                  widget.onChanged(selected);
                  if (selected != null) {
                    widget.onBarangaySelected?.call(selected);
                  }
                },
        ),
      ],
    );
  }
}
