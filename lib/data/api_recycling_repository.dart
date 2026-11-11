import '../core/app_config.dart';
import '../domain/models.dart';
import '../domain/map_location.dart';
import 'api_client.dart';
import 'recycling_repository.dart';
import 'upload_image.dart';

class ApiRecyclingRepository extends RecyclingRepository {
  final ApiClient client;
  Map<String, dynamic> _state = {};
  ApiRecyclingRepository(this.client);
  @override
  bool get remote => true;
  @override
  Map<String, String> get mediaHeaders => client.authHeaders;
  @override
  List<String> get availableCategories =>
      ((_state['categories'] as List?) ?? [])
          .map((row) => '${row['name']}')
          .toList();
  @override
  List<AppNotice> get remoteNotices {
    final role = _state['user']?['role'] == 'buyer'
        ? UserRole.buyer
        : UserRole.household;
    return [
      for (final row in (_state['notifications'] as List? ?? []))
        AppNotice(
          '${row['title']}',
          '${row['body']}',
          role,
          pickupId: row['pickup_id']?.toString(),
        ),
      for (final row in (_state['announcements'] as List? ?? []))
        AppNotice(
          '${row['title']}',
          '${row['body']}',
          role,
          announcementAudience: '${row['audience'] ?? 'all'}',
        ),
    ];
  }

  @override
  Future<List<Pickup>> loadPickups() async {
    _state = Map<String, dynamic>.from(await client.request('state') as Map);
    return (_state['pickups'] as List).map((raw) {
      final row = raw as Map;
      final pin = row['location_pin'] as Map?;
      return Pickup(
        id: '${row['id']}',
        ownerId: '${row['owner_id']}',
        ownerName: '${row['owner_name']}',
        category: '${row['category']}',
        estimatedKg: (row['estimated_kg'] as num).toDouble(),
        barangay: '${row['barangay_name']}',
        streetPurok: '${row['street_purok']}',
        cityMunicipality: '${row['city_name']}',
        cityMunicipalityCode: '${row['city_code']}',
        barangayCode: '${row['barangay_code']}',
        windowStart: DateTime.parse('${row['window_start']}').toLocal(),
        windowEnd: DateTime.parse('${row['window_end']}').toLocal(),
        status: PickupStatus.values.firstWhere(
          (state) => state.apiValue == row['status'],
        ),
        buyerId: row['buyer_id']?.toString(),
        buyerName: row['buyer_name'] as String?,
        actualKg: (row['actual_kg'] as num?)?.toDouble(),
        pricePerKg: (row['price_per_kg'] as num?)?.toDouble(),
        buyerVerified: row['buyer_verified'] == true,
        notes: '${row['notes']}',
        locationPin: pin == null
            ? null
            : GeoPin(
                (pin['lat'] as num).toDouble(),
                (pin['lng'] as num).toDouble(),
                source: '${pin['source']}',
              ),
        photoUrl: row['photo_url'] == null
            ? null
            : AppConfig.endpoint('${row['photo_url']}').toString(),
      );
    }).toList();
  }

  @override
  Future<List<Offer>> loadOffers() async => (_state['offers'] as List? ?? [])
      .map(
        (raw) => Offer(
          id: '${raw['id']}',
          pickupId: '${raw['pickup_id']}',
          buyerId: '${raw['buyer_id']}',
          buyerName: '${raw['buyer_name']}',
          buyerLocation: raw['buyer_location'] as String? ?? '',
          pricePerKg: (raw['price_per_kg'] as num).toDouble(),
          verified: raw['verified'] == true,
        ),
      )
      .toList();
  @override
  Future<List<ChatMessage>> loadMessages() async =>
      (_state['messages'] as List? ?? [])
          .map(
            (raw) =>
                ChatMessage.fromJson(Map<String, dynamic>.from(raw as Map)),
          )
          .toList();
  @override
  Future<void> publish(AppUser actor, Pickup pickup) async {
    await client.request(
      'pickups',
      method: 'POST',
      body: {
        'client_request_id': pickup.id,
        'category': pickup.category,
        'estimated_weight_kg': pickup.estimatedKg,
        ...pickup.locationPayloadForApi,
        'street_purok': pickup.streetPurok,
        'window_start': pickup.windowStart.toUtc().toIso8601String(),
        'window_end': pickup.windowEnd.toUtc().toIso8601String(),
        'notes': pickup.notes,
        'location_pin': pickup.locationPin == null
            ? null
            : _pin(pickup.locationPin!),
        'photo_data_uri': pickup.photo == null
            ? null
            : await prepareUploadImage(pickup.photo!),
      },
    );
  }

  Map<String, Object> _pin(GeoPin pin) => {
    'lat': pin.latitude,
    'lng': pin.longitude,
    'source': pin.source,
    'label': pin.label,
  };
  @override
  Future<void> sendOffer(AppUser actor, String pickupId, double price) async {
    await client.request(
      'pickups/$pickupId/offers',
      method: 'POST',
      body: {'price_per_kg': price},
    );
  }

  @override
  Future<void> selectOffer(AppUser actor, String offerId) async {
    await client.request('offers/$offerId/select', method: 'POST');
  }

  @override
  Future<void> advancePickup(AppUser actor, String pickupId) async {
    await client.request('pickups/$pickupId/advance', method: 'POST');
  }

  @override
  Future<void> recordCollection(
    AppUser actor,
    String pickupId,
    double kg,
    double price,
    bool cashPaid,
  ) async {
    await client.request(
      'pickups/$pickupId/collection',
      method: 'POST',
      body: {
        'actual_weight_kg': kg,
        'final_price_per_kg': price,
        'cash_paid': cashPaid,
      },
    );
  }

  @override
  Future<void> confirmCollection(
    AppUser actor,
    String pickupId, {
    required bool accepted,
  }) async {
    await client.request(
      'pickups/$pickupId/confirm',
      method: 'POST',
      body: {'accepted': accepted},
    );
  }

  @override
  Future<void> cancelPickup(AppUser actor, String pickupId) async {
    await client.request('pickups/$pickupId/cancel', method: 'POST');
  }

  @override
  Future<ChatMessage> sendMessage(
    AppUser actor,
    String pickupId,
    String text,
  ) async {
    final result = await client.request(
      'pickups/$pickupId/messages',
      method: 'POST',
      body: {'text': text},
    );
    return ChatMessage.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<void> updateLocationPin(
    AppUser actor,
    String pickupId,
    GeoPin pin,
  ) async {
    if (pin.location == null) {
      throw StateError('Choose a municipality and barangay before saving.');
    }
    await client.request(
      'pickups/$pickupId/pin',
      method: 'PUT',
      body: {
        'location_pin': _pin(pin),
        'cities_municipalities': pin.location!.city.code,
        'barangays': pin.location!.barangay.code,
        'street_purok': pin.street,
      },
    );
  }
}

extension on Pickup {
  Map<String, String> get locationPayloadForApi => {
    'cities_municipalities': cityMunicipalityCode,
    'barangays': barangayCode,
  };
}
