import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'google_maps_runtime.dart';
import 'route_interaction_gate.dart';

export 'google_maps_runtime.dart' show supportsGoogleMaps;

/// Google Maps renderer shared by address editing and the buyer pickup route.
class GoogleMapView extends StatefulWidget {
  final Map<String, dynamic> configuration;
  final ValueChanged<Map<String, dynamic>> onMessage;
  const GoogleMapView({
    super.key,
    required this.configuration,
    required this.onMessage,
  });

  @override
  State<GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<GoogleMapView> {
  late final Future<void> initialization = initializeGoogleMaps();

  @override
  Widget build(BuildContext context) {
    if (!supportsGoogleMaps) {
      return const Center(
        child: Text('Google Maps is available on Android, iOS and Chrome.'),
      );
    }
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                snapshot.error.toString().replaceFirst('Bad state: ', ''),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return RouteInteractionGate(
          builder: (context, interactive) {
            // Browser platform views must leave the hit-test surface while a
            // Flutter dialog is on top; otherwise they intercept its buttons.
            if (!interactive) return const ColoredBox(color: Color(0xFFEAF5EF));
            return _GoogleMapCanvas(
              configuration: widget.configuration,
              onMessage: widget.onMessage,
            );
          },
        );
      },
    );
  }
}

class _GoogleMapCanvas extends StatefulWidget {
  final Map<String, dynamic> configuration;
  final ValueChanged<Map<String, dynamic>> onMessage;
  const _GoogleMapCanvas({
    required this.configuration,
    required this.onMessage,
  });
  @override
  State<_GoogleMapCanvas> createState() => _GoogleMapCanvasState();
}

class _GoogleMapCanvasState extends State<_GoogleMapCanvas> {
  GoogleMapController? controller;
  Set<Marker> markers = {};
  Set<Polyline> leaders = {};
  MapType mapType = MapType.normal;
  bool preparing = true;
  String? error;
  int generation = 0;
  double zoom = 14;
  static final _icons = <String, Future<BitmapDescriptor>>{};
  static const colors = [
    Color(0xFF008B57),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
    Color(0xFFDC2626),
  ];
  List<Map<String, dynamic>> get points =>
      (widget.configuration['markers'] as List? ?? [])
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
  List<LatLng> get route => (widget.configuration['route'] as List? ?? [])
      .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
      .toList();
  LatLng position(Map<String, dynamic> point) => LatLng(
    (point['lat'] as num).toDouble(),
    (point['lng'] as num).toDouble(),
  );
  bool get editable => widget.configuration['editable'] == true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant _GoogleMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.configuration) !=
        jsonEncode(widget.configuration)) {
      _prepare();
      final old = oldWidget.configuration;
      if (old['revision'] != widget.configuration['revision'] ||
          jsonEncode(old['route']) !=
              jsonEncode(widget.configuration['route']) ||
          (widget.configuration['fit'] != false &&
              jsonEncode(old['markers']) !=
                  jsonEncode(widget.configuration['markers']))) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
      }
    }
  }

  Future<void> _prepare() async {
    final token = ++generation;
    final entries = points;
    final result = <Marker>{};
    final lines = <Polyline>{};
    try {
      for (var i = 0; i < entries.length; i++) {
        final point = entries[i];
        final original = position(point);
        final origin = point['origin'] == true;
        final color = origin
            ? const Color(0xFF2563EB)
            : colors[math.max(
                    0,
                    i - (entries.first['origin'] == true ? 1 : 0),
                  ) %
                  colors.length];
        final label = origin ? 'S' : '${point['number'] ?? ''}';
        // Separate near-identical stop pins visually without changing saved
        // coordinates or the actual road route. A leader retains the endpoint.
        final degreesPerPixel = 360 / (256 * math.pow(2, zoom));
        final longitudeRadius = degreesPerPixel * 44;
        final latitudeRadius =
            longitudeRadius * math.cos(original.latitude * math.pi / 180);
        final nearby = entries
            .where(
              (other) =>
                  (position(other).latitude - original.latitude).abs() <
                      latitudeRadius &&
                  (position(other).longitude - original.longitude).abs() <
                      longitudeRadius,
            )
            .toList();
        var display = original;
        if (!editable && nearby.length > 1) {
          final index = nearby.indexOf(point);
          final angle = 2 * math.pi * index / nearby.length;
          display = LatLng(
            original.latitude + latitudeRadius * math.sin(angle),
            original.longitude + longitudeRadius * math.cos(angle),
          );
          lines.add(
            Polyline(
              polylineId: PolylineId('leader-$i'),
              points: [original, display],
              color: color,
              width: 2,
            ),
          );
        }
        final icon = await _icons.putIfAbsent(
          '$color:$label:$origin',
          () => _pinIcon(color, label, origin),
        );
        if (!mounted || token != generation) return;
        result.add(
          Marker(
            markerId: MarkerId('pin-$i'),
            position: display,
            icon: icon,
            anchor: const Offset(.5, 1),
            draggable: editable,
            infoWindow: InfoWindow(
              title: '${point['title'] ?? point['label'] ?? 'Pickup pin'}',
            ),
            onDragEnd: editable ? _select : null,
          ),
        );
      }
      if (!mounted || token != generation) return;
      setState(() {
        markers = result;
        leaders = lines;
        preparing = false;
        error = null;
      });
    } catch (_) {
      if (mounted && token == generation) {
        setState(() {
          preparing = false;
          error = 'Map pins could not load. Close and reopen the map to retry.';
        });
      }
    }
  }

  static Future<BitmapDescriptor> _pinIcon(
    Color color,
    String label,
    bool vehicle,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(2);
    final path = Path()
      ..moveTo(24, 58)
      ..cubicTo(20, 49, 3, 33, 3, 23)
      ..cubicTo(3, -4, 45, -4, 45, 23)
      ..cubicTo(45, 33, 28, 49, 24, 58)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: vehicle
            ? String.fromCharCode(Icons.two_wheeler.codePoint)
            : label.isEmpty
            ? '•'
            : label,
        style: TextStyle(
          color: Colors.white,
          fontSize: vehicle ? 23 : 18,
          fontWeight: FontWeight.bold,
          fontFamily: vehicle ? Icons.two_wheeler.fontFamily : null,
        ),
      ),
    )..layout(maxWidth: 40);
    painter.paint(
      canvas,
      Offset(24 - painter.width / 2, 23 - painter.height / 2),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(96, 120);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    painter.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 48,
      height: 60,
    );
  }

  void _select(LatLng point) => widget.onMessage({
    'type': 'pin',
    'lat': point.latitude,
    'lng': point.longitude,
  });

  Future<void> _fit() async {
    final map = controller;
    if (!mounted || map == null) return;
    final all = [...points.map(position), ...route];
    if (all.isEmpty) return;
    try {
      if (all.length == 1 || all.every((p) => p == all.first)) {
        await map.animateCamera(
          CameraUpdate.newLatLngZoom(
            all.first,
            (widget.configuration['zoom'] as num? ?? 15).toDouble(),
          ),
        );
      } else {
        final south = all.map((p) => p.latitude).reduce(math.min);
        final north = all.map((p) => p.latitude).reduce(math.max);
        final west = all.map((p) => p.longitude).reduce(math.min);
        final east = all.map((p) => p.longitude).reduce(math.max);
        await map.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(south - .0005, west - .0005),
              northeast: LatLng(north + .0005, east + .0005),
            ),
            40,
          ),
        );
      }
    } catch (_) {
      /* The map can be disposed when collapsed during a camera update. */
    }
  }

  @override
  void dispose() {
    generation++;
    // GoogleMap owns and disposes its controller when the platform view leaves.
    controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: points.isEmpty
                ? const LatLng(9.85, 124.15)
                : position(points.first),
            zoom: 14,
          ),
          onMapCreated: (map) {
            controller = map;
            _fit();
          },
          onCameraMove: (camera) => zoom = camera.zoom,
          onCameraIdle: _prepare,
          markers: markers,
          polylines: {
            ...leaders,
            if (route.isNotEmpty)
              Polyline(
                polylineId: const PolylineId('road-route'),
                points: route,
                color: const Color(0xFF2563EB),
                width: 5,
              ),
          },
          mapType: mapType,
          onTap: editable ? _select : null,
          onLongPress: editable ? _select : null,
          gestureRecognizers: editable
              ? {
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                }
              : {},
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          compassEnabled: true,
        ),
      ),
      Positioned(
        top: 8,
        right: 8,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<MapType>(
                value: mapType,
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: MapType.normal,
                    child: Text('Street'),
                  ),
                  DropdownMenuItem(
                    value: MapType.hybrid,
                    child: Text('Satellite'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => mapType = value);
                },
              ),
            ),
          ),
        ),
      ),
      if (preparing) const Center(child: CircularProgressIndicator()),
      if (error != null) Center(child: Text(error!)),
    ],
  );
}
