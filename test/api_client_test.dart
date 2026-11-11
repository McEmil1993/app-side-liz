import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:easy_scrap/data/api_client.dart';
import 'package:easy_scrap/data/api_auth_repository.dart';
import 'package:easy_scrap/data/api_recycling_repository.dart';
import 'package:easy_scrap/data/upload_image.dart';
import 'package:easy_scrap/domain/models.dart';

class MemoryTokens implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async {
    value = token;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

final userJson = <String, Object?>{
  'id': 123,
  'firstname': 'Ana',
  'middlename': null,
  'lastname': 'Reyes',
  'suffix': null,
  'role': 'household',
  'username': 'ana',
  'email': 'ana@example.invalid',
  'contact': '09170000000',
  'street_purok': 'Purok 1',
  'cities_municipalities': '071244000',
  'barangays': '071244017',
  'buyer_verified': false,
  'verification_status': 'not_submitted',
  'avatar_data_uri': null,
  'location_pin': {
    'lat': 10.06,
    'lng': 124.28,
    'source': 'manual',
    'label': 'Home',
  },
  'location_names': {
    'cities_municipalities': 'Trinidad',
    'barangays': 'San Vicente',
  },
};
void main() {
  test(
    'Vercel protection is a deployment error and preserves the app session',
    () async {
      for (final html in [false, true]) {
        final store = MemoryTokens()..value = 'valid-session';
        var expired = 0;
        final client =
            ApiClient(
                store: store,
                client: MockClient(
                  (_) async => html
                      ? http.Response(
                          '<html><title>Authentication Required</title><a href="https://vercel.com/sso">Vercel</a></html>',
                          200,
                          headers: {'content-type': 'text/html'},
                        )
                      : http.Response(
                          jsonEncode({
                            'message': 'Protected by Vercel Authentication',
                          }),
                          401,
                          headers: {'content-type': 'application/json'},
                        ),
                ),
              )
              ..token = 'valid-session'
              ..onSessionExpired = () => expired++;
        await expectLater(
          client.request('me'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', 503)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Production Domain'),
                ),
          ),
        );
        expect(expired, 0);
        expect(store.value, 'valid-session');
        client.httpClient.close();
      }
    },
  );
  test(
    'normal announcement text mentioning Vercel is still accepted',
    () async {
      final client = ApiClient(
        store: MemoryTokens(),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': {'title': 'Protected by Vercel Authentication'},
            }),
            200,
          ),
        ),
      );
      expect(
        (await client.request('state'))['title'],
        'Protected by Vercel Authentication',
      );
      client.httpClient.close();
    },
  );
  test(
    'API login and restore use bearer auth, preserve codes and securely persist the session',
    () async {
      final store = MemoryTokens();
      final transport = MockClient((request) async {
        expect(request.url.path.startsWith('/api/v1/mobile/'), true);
        if (request.url.path.endsWith('/auth/login')) {
          expect(jsonDecode(request.body)['identifier'], 'ana');
          return http.Response(
            jsonEncode({
              'data': {'token': 'test-token', 'user': userJson},
            }),
            200,
          );
        }
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(jsonEncode({'data': userJson}), 200);
      });
      final client = ApiClient(client: transport, store: store),
          auth = ApiAuthRepository(ApiClient(client: transport, store: store));
      final signedIn = await ApiAuthRepository(
        client,
      ).signIn('ana', 'ExamplePassword!');
      expect(signedIn.cityMunicipalityCode, '071244000');
      expect(signedIn.barangay, 'San Vicente');
      expect(store.value, 'test-token');
      expect((await auth.restoreSession())!.id, '123');
      expect(auth.profilePin!.latitude, 10.06);
    },
  );
  test(
    'expired sessions clear tokens and show server validation errors',
    () async {
      final store = MemoryTokens()..value = 'expired';
      int expired = 0;
      final client = ApiClient(
        store: store,
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'message': 'Session expired.'}), 401),
        ),
      )..onSessionExpired = () => expired++;
      await client.restore();
      await expectLater(client.request('me'), throwsA(isA<ApiException>()));
      expect(store.value, null);
      expect(expired, 1);
      final validation = ApiClient(
        store: MemoryTokens(),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message': 'Invalid',
              'errors': {'barangays': 'Select a matching barangay.'},
            }),
            422,
          ),
        ),
      );
      await expectLater(
        validation.request('me', method: 'PUT', body: {}),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Select a matching barangay.',
          ),
        ),
      );
    },
  );
  test(
    'server snapshot maps statuses, photos and notices without extra list requests',
    () async {
      int calls = 0;
      final client = ApiClient(
        store: MemoryTokens(),
        client: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode({
              'data': {
                'user': userJson,
                'categories': [
                  {'name': 'Plastic'},
                ],
                'pickups': [
                  {
                    'id': '7',
                    'owner_id': '123',
                    'owner_name': 'Ana',
                    'category': 'Plastic',
                    'estimated_kg': 8,
                    'city_code': '071244000',
                    'city_name': 'Trinidad',
                    'barangay_code': '071244017',
                    'barangay_name': 'San Vicente',
                    'street_purok': 'Purok 1',
                    'status': 'awaiting_confirmation',
                    'window_start': '2026-10-20T01:00:00Z',
                    'window_end': '2026-10-20T04:00:00Z',
                    'actual_kg': 7.5,
                    'price_per_kg': 12,
                    'buyer_id': '124',
                    'buyer_name': 'Ben',
                    'buyer_verified': true,
                    'notes': '',
                    'photo_url': 'mobile/pickups/7/photo',
                    'location_pin': {
                      'lat': 10.06,
                      'lng': 124.28,
                      'source': 'manual',
                    },
                  },
                ],
                'offers': [
                  {
                    'id': '8',
                    'pickup_id': '7',
                    'buyer_id': '124',
                    'buyer_name': 'Ben',
                    'price_per_kg': 12,
                    'verified': true,
                  },
                ],
                'messages': [
                  {
                    'pickup_id': '7',
                    'sender_id': '124',
                    'text': 'Hello',
                    'sent_at': '2026-10-20T00:00:00Z',
                  },
                ],
                'notifications': [
                  {
                    'title': 'Confirm collection',
                    'body': 'Review weight',
                    'pickup_id': 7,
                  },
                ],
                'announcements': [
                  {
                    'title': 'LGU update',
                    'body': 'Collection schedule',
                    'audience': 'all',
                  },
                ],
              },
            }),
            200,
          );
        }),
      );
      client.token = 'test-token';
      final repository = ApiRecyclingRepository(client);
      final pickups = await repository.loadPickups();
      expect(pickups.single.status, PickupStatus.awaitingConfirmation);
      expect(pickups.single.amount, 90);
      expect(
        pickups.single.photoUrl,
        endsWith('/api/v1/mobile/pickups/7/photo'),
      );
      expect((await repository.loadOffers()).single.verified, true);
      expect((await repository.loadMessages()).single.text, 'Hello');
      expect(repository.remoteNotices.first.pickupId, '7');
      expect(repository.remoteNotices.last.announcementAudience, 'all');
      expect(repository.remoteNotices.last.title, 'LGU update');
      expect(repository.availableCategories, ['Plastic']);
      expect(calls, 1);
      expect(repository.mediaHeaders['Authorization'], 'Bearer test-token');
    },
  );
  test(
    'upload preparation crops, rotates and compresses images under the server file limit',
    () async {
      final bytes = Uint8List.fromList(
        image.encodePng(image.Image(width: 1200, height: 800)),
      );
      final uri = await prepareUploadImage(
        bytes,
        square: true,
        turns: 1,
        zoom: 1.5,
      );
      final jpg = base64Decode(uri.split(',').last);
      expect(jpg.length, lessThanOrEqualTo(512 * 1024));
      final result = image.decodeJpg(jpg)!;
      expect(result.width, result.height);
      expect(result.width, lessThanOrEqualTo(1024));
      await expectLater(
        prepareUploadImage(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<StateError>()),
      );
    },
  );
}
