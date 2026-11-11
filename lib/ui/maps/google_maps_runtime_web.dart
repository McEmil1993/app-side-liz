import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

const supportsGoogleMaps = true;
Future<void>? _initialization;

Future<void> initializeGoogleMaps() => _initialization ??= _load();

Future<void> _load() async {
  const key = String.fromEnvironment('GOOGLE_MAPS_WEB_API_KEY');
  if (key.isEmpty) {
    throw StateError(
      'Chrome needs a separate Google Maps website key. Run with '
      '--dart-define=GOOGLE_MAPS_WEB_API_KEY=your_browser_key. '
      'The Android key works only in the Android app.',
    );
  }
  final loaded = Completer<void>();
  final script = web.HTMLScriptElement()
    ..async = true
    ..src = Uri.https('maps.googleapis.com', '/maps/api/js', {
      'key': key,
      'v': 'weekly',
    }).toString();
  script.onload = ((web.Event _) => loaded.complete()).toJS;
  script.onerror = ((web.Event _) {
    if (!loaded.isCompleted) {
      loaded.completeError(
        StateError(
          'Google Maps could not load. Check your connection and browser key.',
        ),
      );
    }
  }).toJS;
  web.document.head!.appendChild(script);
  await loaded.future.timeout(const Duration(seconds: 30));
}
