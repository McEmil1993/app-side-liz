import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/map_service.dart';
import '../../data/device_location_service.dart';
import '../../domain/map_location.dart';
import '../../domain/models.dart';
import '../widgets.dart';
import 'google_map_view.dart';
import 'map_visibility.dart';

class RouteMap extends StatefulWidget {
  final List<Pickup> stops;
  final MapAddress originAddress;
  final GeoPin? originPin;
  const RouteMap({
    super.key,
    required this.stops,
    required this.originAddress,
    this.originPin,
  });
  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  List<Map<String, dynamic>> markers = [];
  RoadRoute? road;
  String? error;
  bool loading = false;
  bool locating = false;
  GeoPin? gpsPin;
  String? gpsError;
  int generation = 0;
  String fingerprint(RouteMap widget) =>
      '${widget.originAddress.key}|${widget.originPin?.toJson()}|${widget.stops.map((p) => '${p.id}:${p.mapAddress.key}:${p.locationPin?.toJson()}').join('|')}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (fingerprint(oldWidget) != fingerprint(widget)) _load();
  }

  Future<void> _load({bool retry = false}) async {
    final token = ++generation;
    if (!supportsGoogleMaps || widget.stops.isEmpty) {
      setState(() {
        loading = false;
        markers = [];
        road = null;
        error = null;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
      road = null;
      markers = [];
    });
    try {
      final points = <GeoPin>[];
      final labels = <Map<String, dynamic>>[];
      final start =
          gpsPin ??
          widget.originPin ??
          await MapService.instance.resolve(widget.originAddress);
      if (start == null) {
        throw StateError(
          'Starting location not found. Set your map pin in Profile.',
        );
      }
      points.add(start);
      labels.add({
        ...start.toJson(),
        'origin': true,
        'number': 'S',
        'title': gpsPin?.label ?? 'Profile start: ${widget.originAddress.full}',
      });
      for (final item in widget.stops.indexed) {
        final pickup = item.$2;
        final pin =
            pickup.locationPin ??
            await MapService.instance.resolve(pickup.mapAddress);
        if (pin == null) {
          throw StateError(
            'Location not found for ${pickup.ownerName}. Confirm that pickup pin before routing.',
          );
        }
        points.add(pin);
        labels.add({
          ...pin.toJson(),
          'number': '${item.$1 + 1}',
          'title':
              '${item.$1 + 1}. ${pickup.ownerName} · ${pickup.mapAddress.full}${pin.confirmed ? '' : ' (approximate pin)'}',
        });
      }
      if (!mounted || token != generation) return;
      setState(() => markers = labels);
      final result = await MapService.instance.route(points, retry: retry);
      if (mounted && token == generation) setState(() => road = result);
    } catch (e) {
      if (mounted && token == generation) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'Road route could not connect. Please retry.',
        );
      }
    } finally {
      if (mounted && token == generation) setState(() => loading = false);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() {
      locating = true;
      gpsError = null;
    });
    try {
      final found = await DeviceLocationService.current();
      if (!mounted) return;
      setState(() => gpsPin = found);
      await _load();
    } catch (e) {
      if (mounted) {
        setState(
          () => gpsError = e is StateError
              ? e.message.toString()
              : 'Could not get your location. Check location access and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.all(12),
    child: MapVisibility(
      initiallyExpanded: true,
      header: Row(
        children: [
          const Icon(Icons.route_outlined, color: AppColors.green),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Road route',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      summary: Text(
        gpsPin == null
            ? 'Profile start: ${widget.originAddress.full}'
            : gpsPin!.label,
        style: const TextStyle(color: AppColors.muted, fontSize: 11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: locating || loading ? null : _useMyLocation,
                icon: locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(
                  locating ? 'Finding your location...' : 'Use my location',
                ),
              ),
              if (gpsPin != null)
                TextButton(
                  onPressed: locating || loading
                      ? null
                      : () {
                          setState(() {
                            gpsPin = null;
                            gpsError = null;
                          });
                          _load();
                        },
                  child: const Text('Use profile start'),
                ),
            ],
          ),
          if (gpsError != null)
            Text(
              gpsError!,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9B6500)),
            ),
          const Text(
            'Blue vehicle: your starting point. GPS is refreshed when you tap Use my location.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final item in widget.stops.indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 18,
                      color: [
                        const Color(0xFF008B57),
                        const Color(0xFFD97706),
                        const Color(0xFF7C3AED),
                        const Color(0xFFDB2777),
                        const Color(0xFF0891B2),
                        const Color(0xFFDC2626),
                      ][item.$1 % 6],
                    ),
                    Text(
                      '${item.$1 + 1}. ${item.$2.ownerName}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.stops.isEmpty)
            const EmptyState(
              'No route yet',
              'Accepted pickup locations will appear here.',
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 300,
                color: AppColors.mint,
                child: GoogleMapView(
                  configuration: {
                    'markers': markers,
                    'editable': false,
                    'route':
                        road?.geometry
                            .map((point) => [point.latitude, point.longitude])
                            .toList() ??
                        [],
                  },
                  onMessage: (_) {},
                ),
              ),
            ),

          if (road != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${(road!.metres / 1000).toStringAsFixed(1)} km · ${(road!.seconds / 60).ceil()} min driving estimate',
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xFF9B6500), fontSize: 12),
              ),
            ),
          const SizedBox(height: 10),
          const Text(
            'Road route: OSRM / © OpenStreetMap contributors. Stops follow pickup schedule order; times exclude stops and live traffic. Confirm approximate pins before pickup.',
            style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
          ),
          if (supportsGoogleMaps && widget.stops.isNotEmpty)
            TextButton.icon(
              onPressed: loading ? null : () => _load(retry: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh road route'),
            ),
        ],
      ),
    ),
  );
}
