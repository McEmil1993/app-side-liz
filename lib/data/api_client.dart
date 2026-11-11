import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/app_config.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  final FlutterSecureStorage storage;
  SecureTokenStore({this.storage = const FlutterSecureStorage()});
  String get key =>
      'easyscrap_session_${Uri.parse(AppConfig.apiBaseUrl).host}_${Uri.parse(AppConfig.apiBaseUrl).port}';
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String token) => storage.write(key: key, value: token);
  @override
  Future<void> clear() => storage.delete(key: key);
}

class ApiException extends StateError {
  final int status;
  ApiException(super.message, this.status);
  @override
  String toString() => message.toString();
}

class ApiClient {
  final http.Client httpClient;
  final TokenStore tokenStore;
  String? token;
  void Function()? onSessionExpired;
  Future<void> Function()? onAuthenticated;
  Future<void> Function()? onSessionCleared;
  ApiClient({http.Client? client, TokenStore? store})
    : httpClient = client ?? http.Client(),
      tokenStore = store ?? SecureTokenStore();
  Map<String, String> get authHeaders =>
      token == null ? {} : {'Authorization': 'Bearer $token'};
  Future<void> restore() async {
    token = await tokenStore.read();
    if (token != null) await onAuthenticated?.call();
  }

  Future<void> setToken(String value) async {
    await tokenStore.write(value);
    token = value;
    await onAuthenticated?.call();
  }

  Future<void> clearToken() async {
    token = null;
    await onSessionCleared?.call();
    await tokenStore.clear();
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
    bool mobile = true,
  }) async {
    try {
      final uri = AppConfig.endpoint(mobile ? 'mobile/$path' : path);
      final request = http.Request(method, uri)
        ..headers.addAll({
          ...authHeaders,
          if (body != null) 'Content-Type': 'application/json',
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await httpClient.send(request).timeout(const Duration(seconds: 30)),
      ).timeout(const Duration(seconds: 30));
      // Deployment protection responses belong to Vercel, not our JWT API.
      // Do not discard a valid app session or report incorrect credentials.
      final bodyText = response.body.toLowerCase();
      final externalError =
          response.statusCode >= 300 ||
          (response.headers['content-type'] ?? '').contains('text/html') ||
          bodyText.trimLeft().startsWith('<');
      if (externalError &&
          (bodyText.contains('protected by vercel authentication') ||
              (bodyText.contains('vercel') &&
                  (bodyText.contains('authentication required') ||
                      bodyText.contains('vercel.com/sso'))))) {
        throw ApiException(
          'The backend URL is protected by Vercel Authentication. Use the public Production Domain from Vercel Settings > Domains, then rebuild the APK.',
          503,
        );
      }
      final payload = response.statusCode == 204
          ? null
          : jsonDecode(response.body);
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && !path.startsWith('auth/')) {
          await clearToken();
          onSessionExpired?.call();
        }
        final fields = payload is Map ? payload['errors'] : null;
        final message = fields is Map && fields.isNotEmpty
            ? fields.values.join('\n')
            : payload is Map
            ? payload['message']
            : null;
        throw ApiException(
          message?.toString() ?? 'Request failed.',
          response.statusCode,
        );
      }
      return payload is Map ? payload['data'] : null;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'The request timed out. Check your connection and retry.',
        408,
      );
    } on FormatException {
      throw ApiException(
        'The server returned an invalid response. Check the API URL.',
        502,
      );
    } on http.ClientException {
      throw ApiException(
        'Cannot reach the API. Check the URL, backend and network connection.',
        0,
      );
    }
  }
}
