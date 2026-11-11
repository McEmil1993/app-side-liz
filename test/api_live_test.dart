import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:image/image.dart' as image;
import 'package:easy_scrap/core/app_config.dart';
import 'package:easy_scrap/data/api_client.dart';
import 'package:easy_scrap/data/api_auth_repository.dart';
import 'package:easy_scrap/data/api_recycling_repository.dart';
import 'package:easy_scrap/data/bohol_locations.dart';
import 'package:easy_scrap/data/upload_image.dart';
import 'package:easy_scrap/domain/registration.dart';
import 'package:easy_scrap/domain/models.dart';
import 'package:easy_scrap/domain/map_location.dart';
import 'api_client_test.dart' show MemoryTokens;

void main() {
  // Capture the real client before Flutter's widget binding installs its HTTP stub.
  final network = const bool.fromEnvironment('LIVE_API_TEST')
      ? HttpClient()
      : null;
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Flutter repositories communicate with the local Express / MySQL API',
    () async {
      expect(
        [
          '127.0.0.1',
          'localhost',
        ].contains(Uri.parse(AppConfig.apiBaseUrl).host),
        true,
      );
      final prefix =
          'flutter_api_test_${DateTime.now().millisecondsSinceEpoch}';
      final artifact = File('.dart_tool/mobile-smoke-users.json');
      await artifact.writeAsString(jsonEncode({'prefix': prefix}));
      final client = ApiClient(
            store: MemoryTokens(),
            client: IOClient(network!),
          ),
          auth = ApiAuthRepository(client),
          repository = ApiRecyclingRepository(client);
      try {
        final user = await auth.register(
          Registration(
            firstname: 'Flutter',
            lastname: 'Integration',
            contact: '09170000000',
            username: prefix,
            email: '$prefix@example.invalid',
            password: 'Fixture-Flutter-2026!',
            barangay: 'San Vicente',
            streetPurok: 'Purok 1',
            role: UserRole.household,
          ),
        );
        expect(user.barangayCode, '071244017');
        expect((await auth.loadProfile()).id, user.id);
        final updated = await auth.updateProfile({
          'middlename': 'Client',
          'street_purok': 'Purok 2',
        });
        expect(updated.middlename, 'Client');
        final bytes = Uint8List.fromList(
          image.encodePng(image.Image(width: 64, height: 64)),
        );
        final photo = await prepareUploadImage(bytes, square: true);
        final avatar = await auth.updateAvatar(photo);
        expect(avatar.avatar, isNotNull);
        final locations = await BoholLocations.load();
        final selection = locations.selection(
          user.cityMunicipalityCode,
          user.barangayCode,
        )!;
        final pin = GeoPin(
          10.06,
          124.28,
          location: selection,
          street: 'Purok 2',
        );
        await auth.savePin(updated, pin);
        expect(auth.profilePin!.latitude, 10.06);
        await repository.loadPickups();
        expect(repository.availableCategories, isNotEmpty);
        final pickup = Pickup(
          id: 'flutter-smoke-post',
          ownerId: user.id,
          ownerName: user.name,
          category: repository.availableCategories.first,
          estimatedKg: 8,
          barangay: user.barangay,
          barangayCode: user.barangayCode,
          cityMunicipality: user.cityMunicipality,
          cityMunicipalityCode: user.cityMunicipalityCode,
          streetPurok: 'Purok 2',
          windowStart: DateTime.now().add(const Duration(days: 1)),
          windowEnd: DateTime.now().add(const Duration(days: 1, hours: 3)),
          photo: bytes,
          locationPin: pin,
        );
        await repository.publish(user, pickup);
        final records = await repository.loadPickups();
        expect(records.length, 1);
        expect(records.single.ownerId, user.id);
        expect(records.single.photoUrl, isNotNull);
        expect(records.single.locationPin!.latitude, 10.06);
        await repository.cancelPickup(user, records.single.id);
        expect(
          (await repository.loadPickups()).single.status,
          PickupStatus.cancelled,
        );
        await auth.signOut();
        expect(client.token, null);
        expect(
          (await auth.signIn(prefix, 'Fixture-Flutter-2026!')).avatar,
          isNotNull,
        );
        final buyer = await auth.register(
          Registration(
            firstname: 'Flutter',
            lastname: 'Buyer',
            contact: '09170000000',
            username: '${prefix}_buyer',
            email: '${prefix}_buyer@example.invalid',
            password: 'Fixture-Flutter-2026!',
            barangay: 'San Vicente',
            streetPurok: 'Purok 1',
            role: UserRole.buyer,
          ),
        );
        expect(buyer.buyerVerified, false);
        await auth.submitVerification(
          'Flutter Test Shop',
          ['business_permit', 'valid_id', 'shop_photo']
              .map(
                (kind) => {
                  'kind': kind,
                  'filename': '$kind.jpg',
                  'data_uri': photo,
                },
              )
              .toList(),
        );
        final review = (await auth.verification())!;
        expect(review['decision'], 'pending');
        final document = await auth.verificationDocument(
          '${review['documents'][0]['id']}',
        );
        expect(document['data_uri'], photo);
        await auth.signOut();
      } finally {
        client.httpClient.close();
      }
    },
    skip: !const bool.fromEnvironment('LIVE_API_TEST', defaultValue: false),
  );
}
