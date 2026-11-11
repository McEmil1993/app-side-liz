abstract final class MapConfig {
  static const reverseGeocoder = String.fromEnvironment(
    'MAP_REVERSE_GEOCODER_URL',
    defaultValue: 'https://photon.komoot.io/reverse',
  );
  static const geocoder = String.fromEnvironment(
    'MAP_GEOCODER_URL',
    defaultValue: 'https://photon.komoot.io/api/',
  );
  static const router = String.fromEnvironment(
    'MAP_ROUTER_URL',
    defaultValue: 'https://router.project-osrm.org/route/v1/driving/',
  );
}
