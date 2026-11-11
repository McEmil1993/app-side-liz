/// Public API URL only. Do not place secrets in Flutter configuration.
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://easy-api.project-domain.site/api/v1',
  );
  static const demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: false,
  );

  /// Keeps /api/v1 when resolving paths such as 'auth/login'.
  static Uri endpoint(String path, {Map<String, String>? query}) {
    final base = '${apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '')}/';
    return Uri.parse(base)
        .resolve(path.replaceFirst(RegExp(r'^/+'), ''))
        .replace(queryParameters: query);
  }
}
