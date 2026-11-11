import 'dart:io';

final supportsGoogleMaps = Platform.isAndroid || Platform.isIOS;
Future<void> initializeGoogleMaps() async {
  if (Platform.isIOS &&
      !const bool.fromEnvironment('GOOGLE_MAPS_IOS_CONFIGURED')) {
    throw StateError(
      'iOS needs a separate Maps SDK for iOS key in AppDelegate. '
      'See docs/maps.md before enabling GOOGLE_MAPS_IOS_CONFIGURED.',
    );
  }
}
