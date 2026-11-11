import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/map_service.dart';
import '../../data/bohol_locations.dart';
import '../../data/device_location_service.dart';
import '../../domain/location.dart';
import '../location_fields.dart';
import '../../domain/map_location.dart';
import '../widgets.dart';
import 'google_map_view.dart';
import 'map_visibility.dart';

class AddressMap extends StatefulWidget {
  final MapAddress address;
  final bool userLocation;
  final GeoPin? savedPin;
  final FutureOr<void> Function(GeoPin)? onSave;
  final String title;
  final ValueChanged<GeoPin?>? onResolved;
  final MapService? service;
  const AddressMap({
    super.key,
    required this.address,
    this.userLocation = false,
    this.savedPin,
    this.onSave,
    this.onResolved,
    this.service,
    this.title = 'Pickup location',
  });
  @override
  State<AddressMap> createState() => _AddressMapState();
}

class _AddressMapState extends State<AddressMap> {
  GeoPin? pin, draft;
  bool editing = false, loading = false, saving = false;
  String? error;
  int generation = 0;
  int revision = 0;
  ReverseAddress? nearby;
  LocationSelection? selectedAddress;
  LocationOption? selectedCity;
  final street = TextEditingController();
  MapService get service => widget.service ?? MapService.instance;
  bool preserveManualPin = false;

  Future<void> _previewPin(GeoPin point, {bool preservePosition = true}) async {
    final token = ++generation;
    setState(() {
      draft = point;
      preserveManualPin = preservePosition;
      saving = true;
      loading = false;
      nearby = null;
      selectedAddress = null;
      selectedCity = null;
      street.clear();
      error = null;
    });
    ReverseAddress? result;
    LocationSelection? matched;
    try {
      result = await service.reverseAddress(point);
      final locations = await BoholLocations.load();
      if (result != null) {
        matched = await locations.matchReverseWithPostcode(
          result,
          service.municipalityPostcode,
        );
      }
    } catch (_) {
      if (!mounted || token != generation) return;
      error =
          'Address lookup could not connect. Retry, or choose the municipality and barangay below.';
    }
    if (!mounted || token != generation) return;
    setState(() {
      nearby = result;
      selectedAddress = matched;
      selectedCity = matched?.city;
      street.text = result?.street ?? '';
      saving = false;
      if (result == null && error == null) {
        error =
            'No mapped address found here. Choose the municipality and barangay below.';
      }
      if (result != null && matched == null) {
        error =
            'The provider could not identify a unique barangay and municipality. Choose them below; your selected coordinates will stay in place.';
      }
    });
  }

  void _startEditing() {
    generation++;
    setState(() {
      editing = true;
      preserveManualPin = false;
      selectedAddress = null;
      draft = pin;
      loading = false;
      saving = false;
      error = null;
    });
    if (pin != null) _previewPin(pin!, preservePosition: false);
  }

  Future<void> _useMyLocation() async {
    final token = ++generation;
    setState(() {
      editing = true;
      saving = true;
      error = null;
    });
    try {
      final gps = await DeviceLocationService.current();
      if (!mounted || token != generation) return;
      revision++;
      await _previewPin(GeoPin(gps.latitude, gps.longitude, label: gps.label));
    } catch (failure) {
      if (mounted && token == generation) {
        setState(() {
          saving = false;
          error = failure.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  Future<void> _autoPin(
    LocationOption city, [
    LocationSelection? address,
  ]) async {
    final token = ++generation;
    setState(() {
      selectedCity = city;
      selectedAddress = address;
      preserveManualPin = false;
      nearby = null;
      draft = null;
      saving = true;
      street.clear();
      error = null;
    });
    try {
      final found = address == null
          ? await service.resolveMunicipality(city.name)
          : await service.resolve(
              MapAddress(
                street: '',
                barangay: address.barangay.name,
                city: city.name,
                barangayCode: address.barangay.code,
              ),
            );
      if (!mounted || token != generation) return;
      setState(() {
        draft = found;
        revision++;
        if (found == null) {
          error =
              'Municipality could not be located. Retry or tap the map to place the pin.';
        }
        if (found?.source == 'municipality' && address != null) {
          error =
              'Only the ${city.name} town center was found, not ${address.barangay.name}. Tap your actual location or use GPS before saving.';
        }
      });
    } catch (_) {
      if (!mounted || token != generation) return;
      setState(
        () => error =
            'Location search could not connect. Retry or tap the map to place the pin.',
      );
    } finally {
      if (mounted && token == generation) setState(() => saving = false);
    }
  }

  Future<void> _savePin() async {
    final current = draft;
    final selected = selectedAddress;
    if (current == null ||
        saving ||
        selected == null ||
        current.source == 'municipality') {
      return;
    }
    final saved = GeoPin(
      current.latitude,
      current.longitude,
      source: current.source,
      label: MapAddress(
        street: street.text.trim(),
        barangay: selected.barangay.name,
        city: selected.city.name,
      ).full,
      location: selected,
      street: street.text.trim(),
    );
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave?.call(saved);
      if (!mounted) return;
      setState(() {
        pin = saved;
        draft = null;
        editing = false;
        revision++;
      });
    } catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _cancel() {
    generation++;
    setState(() {
      editing = false;
      saving = false;
      draft = null;
      nearby = null;
      selectedAddress = null;
      error = null;
      revision++;
    });
  }

  @override
  void dispose() {
    generation++;
    street.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void didUpdateWidget(covariant AddressMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address.key != widget.address.key ||
        oldWidget.savedPin != widget.savedPin) {
      _locate();
    }
  }

  Future<void> _locate() async {
    final token = ++generation;
    revision++;
    pin = widget.savedPin;
    draft = null;
    editing = false;
    error = null;
    loading = false;
    saving = false;
    if (!supportsGoogleMaps || pin != null) {
      if (mounted) setState(() {});
      return;
    }
    setState(() => loading = true);
    try {
      final found = await service.resolve(widget.address);
      if (!mounted || token != generation) return;
      setState(() {
        pin = found;
        if (found == null) {
          error =
              'Address not found. Use Set pin to choose the location on the map.';
        }
      });
      widget.onResolved?.call(found);
    } catch (_) {
      if (mounted && token == generation) {
        setState(
          () => error =
              'Address search could not connect. You can still set the pin manually.',
        );
      }
    } finally {
      if (mounted && token == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = editing ? draft : pin;
    return Surface(
      padding: const EdgeInsets.all(12),
      child: MapVisibility(
        header: Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: AppColors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (loading || saving)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        summary: Text(
          editing
              ? selectedAddress == null
                    ? 'Draft address: finding location or awaiting barangay / municipality selection'
                    : 'Draft address: ${selectedAddress!.barangay.name}, ${selectedAddress!.city.name}, Bohol'
              : 'Entered address: ${widget.address.full}',
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            if (widget.onSave != null) ...[
              Wrap(
                spacing: 8,
                children: [
                  if (!editing)
                    OutlinedButton.icon(
                      onPressed: _startEditing,
                      icon: const Icon(
                        Icons.edit_location_alt_outlined,
                        size: 18,
                      ),
                      label: const Text('Set pin'),
                    ),
                  TextButton.icon(
                    onPressed: saving ? null : _useMyLocation,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Use my location'),
                  ),
                  if (!editing)
                    TextButton(
                      onPressed: loading ? null : _locate,
                      child: const Text('Recenter'),
                    ),
                ],
              ),
              Text(
                editing
                    ? 'Editing pin: tap anywhere, long-press, or hold and drag the marker.'
                    : 'Saved address pin. Use my location reads your device GPS; this marker is not live tracking.',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 260,
                color: AppColors.mint,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AbsorbPointer(
                      absorbing: false,
                      child: GoogleMapView(
                        configuration: {
                          'revision': revision,
                          'editable': editing,
                          'busy': loading || saving,
                          'zoom': current?.source == 'municipality' ? 13 : 16,
                          'markers': [
                            if (current != null)
                              {
                                ...current.toJson(),
                                'origin': widget.userLocation,
                                'title': current.label.isNotEmpty
                                    ? current.label
                                    : editing
                                    ? 'Selected pickup pin'
                                    : widget.address.full,
                              },
                          ],
                          'fit': true,
                        },
                        onMessage: (message) {
                          if (message['type'] == 'pin' && editing) {
                            final point = GeoPin.fromMessage(message);
                            if (point != null) {
                              _previewPin(point);
                            }
                          }
                        },
                      ),
                    ),
                    if (loading || saving)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: Colors.white.withValues(alpha: 0.82),
                            child: Semantics(
                              liveRegion: true,
                              label: 'Updating map location',
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Updating map location...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.darkGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (current != null)
              Text(
                'Pin coordinates: ${current.latitude.toStringAsFixed(6)}, ${current.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            if (!editing &&
                current != null &&
                current.confirmed &&
                current.label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Address near saved pin: ${current.label}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
            if (editing) ...[
              if (saving)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Finding location...'),
                ),
              if (nearby != null)
                Text(
                  'Detected nearby: ${nearby!.label}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                preserveManualPin
                    ? 'Review the detected barangay and municipality. Correcting these fields keeps your chosen coordinates.'
                    : 'Choose a municipality, then a barangay to find its approximate pin. Tap the map or use GPS for your actual pickup spot.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              BoholLocationFields(
                key: ValueKey(
                  'pin-address-$generation-${selectedCity?.code}-${selectedAddress?.barangay.code}',
                ),
                initialCityCode:
                    selectedCity?.code ?? selectedAddress?.city.code ?? '',
                initialBarangayCode: selectedAddress?.barangay.code ?? '',
                onChanged: (value) => setState(() => selectedAddress = value),
                onCityChanged: (city) {
                  generation++;
                  setState(() {
                    selectedCity = city;
                    selectedAddress = null;
                    nearby = null;
                    saving = false;
                    error = null;
                  });
                },
                onBarangaySelected: (value) {
                  if (!preserveManualPin) _autoPin(value.city, value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: street,
                decoration: const InputDecoration(
                  labelText: 'Street / Purok (optional)',
                ),
              ),
              if (selectedCity != null && selectedAddress != null)
                TextButton(
                  onPressed: saving
                      ? null
                      : () => _autoPin(selectedCity!, selectedAddress),
                  child: const Text('Retry automatic pin'),
                ),
            ],
            if (error != null)
              Text(
                error!,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9B6500)),
              ),
            Text(
              editing
                  ? 'Tap the map or drag the pin to your actual pickup spot, then save.'
                  : current == null
                  ? 'Google Maps needs an internet connection.'
                  : current.confirmed
                  ? 'Confirmed map pin · ${current.latitude.toStringAsFixed(5)}, ${current.longitude.toStringAsFixed(5)}'
                  : 'Approximate ${current.source} pin. Purok/house locations need manual confirmation.',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            if (widget.onSave != null && editing) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        current == null ||
                            saving ||
                            current.source == 'municipality' ||
                            selectedAddress == null
                        ? null
                        : _savePin,
                    child: Text(
                      saving ? 'Finding pin address…' : 'Save pin & address',
                    ),
                  ),
                  TextButton(onPressed: _cancel, child: const Text('Cancel')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
