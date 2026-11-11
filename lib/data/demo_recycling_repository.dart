import '../domain/models.dart';
import '../domain/map_location.dart';
import 'recycling_repository.dart';

/// In-memory demo. No API, tokens, payments, geolocation, or artificial delays.
class DemoRecyclingRepository extends RecyclingRepository {
  @override
  Future<void> updateLocationPin(
    AppUser actor,
    String pickupId,
    GeoPin pin,
  ) async {
    final pickup = _get(pickupId);
    _require(
      actor.role == UserRole.household &&
          actor.id == pickup.ownerId &&
          [PickupStatus.open, PickupStatus.accepted].contains(pickup.status),
      'Only the household can adjust a pending or accepted pickup pin.',
    );
    _require(
      pin.valid &&
          (pin.confirmed ||
              (pin.location != null &&
                  ['municipality', 'barangay'].contains(pin.source))),
      'Choose and confirm a valid map pin.',
    );
    _replace(pickup.copyWith(locationPin: pin));
  }

  final List<Pickup> _pickups = [];
  final List<Offer> _offers = [];
  final List<ChatMessage> _messages = [];
  DemoRecyclingRepository({DateTime? now}) {
    final date = (now ?? DateTime.now()).add(const Duration(days: 1));
    DateTime at(int hour) => DateTime(date.year, date.month, date.day, hour);
    void add(
      String id,
      String owner,
      String name,
      String category,
      double kg,
      String barangay,
      PickupStatus status,
      int hour, {
      double distance = 1.2,
    }) => _pickups.add(
      Pickup(
        id: id,
        ownerId: owner,
        ownerName: name,
        category: category,
        estimatedKg: kg,
        barangay: barangay,
        barangayCode:
            const {
              'San Vicente': '071244017',
              'Poblacion': '071244015',
              'Guinobatan': '071244004',
            }[barangay] ??
            '',
        streetPurok: 'Purok 1',
        windowStart: at(hour),
        windowEnd: at(hour + 2),
        distanceKm: distance,
        status: status,
        buyerId: status == PickupStatus.open ? null : 'b1',
        buyerName: status == PickupStatus.open ? null : 'Mang Ben',
        buyerVerified: status != PickupStatus.open,
        pricePerKg: category == 'Plastic' ? 12 : 8,
        actualKg: status == PickupStatus.completed ? kg : null,
      ),
    );
    add(
      'P101',
      'h1',
      'Juan Santos',
      'Plastic',
      8,
      'San Vicente',
      PickupStatus.open,
      9,
    );
    add(
      'P102',
      'h1',
      'Juan Santos',
      'Cardboard',
      5,
      'San Vicente',
      PickupStatus.accepted,
      10,
    );
    add(
      'P103',
      'h2',
      'Maria Dela Cruz',
      'Metal',
      6,
      'Poblacion',
      PickupStatus.accepted,
      11,
      distance: 2.6,
    );
    add(
      'P104',
      'h3',
      'Ana Reyes',
      'Plastic',
      4,
      'Guinobatan',
      PickupStatus.accepted,
      13,
      distance: 3.1,
    );
    add(
      'P105',
      'h4',
      'Pedro Ramos',
      'Cardboard',
      5,
      'Poblacion',
      PickupStatus.open,
      14,
      distance: 2.6,
    );
    add(
      'P100',
      'h1',
      'Juan Santos',
      'Metal',
      3,
      'San Vicente',
      PickupStatus.completed,
      8,
    );
    _offers.addAll(const [
      Offer(
        id: 'O1',
        pickupId: 'P101',
        buyerId: 'b1',
        buyerName: 'Mang Ben',
        pricePerKg: 12,
      ),
      Offer(
        id: 'O2',
        pickupId: 'P101',
        buyerId: 'b2',
        buyerName: 'Lina Recycling',
        pricePerKg: 11,
      ),
    ]);
    _messages.add(
      ChatMessage(
        pickupId: 'P102',
        senderId: 'b1',
        text:
            'Hello! I will collect within your pickup window. Please keep the cardboard dry.',
        sentAt: DateTime.now(),
      ),
    );
  }
  Pickup _get(String id) => _pickups.firstWhere((pickup) => pickup.id == id);
  void _replace(Pickup pickup) =>
      _pickups[_pickups.indexWhere((item) => item.id == pickup.id)] = pickup;
  void _require(bool allowed, String message) {
    if (!allowed) throw StateError(message);
  }

  @override
  Future<List<Pickup>> loadPickups() async => List.unmodifiable(_pickups);
  @override
  Future<List<Offer>> loadOffers() async => List.unmodifiable(_offers);
  @override
  Future<List<ChatMessage>> loadMessages() async =>
      List.unmodifiable(_messages);
  @override
  Future<void> publish(AppUser actor, Pickup pickup) async {
    _require(
      actor.role == UserRole.household && actor.id == pickup.ownerId,
      'Only the household can publish its request.',
    );
    _require(
      pickup.estimatedKg.isFinite &&
          pickup.estimatedKg > 0 &&
          pickup.barangay.trim().isNotEmpty &&
          (pickup.streetPurok.trim().isNotEmpty ||
              pickup.locationPin?.location != null),
      'Enter valid material and address details.',
    );
    _require(
      pickup.windowStart.isAfter(DateTime.now()) &&
          pickup.windowEnd.isAfter(pickup.windowStart),
      'Choose a future pickup window.',
    );
    _pickups.insert(0, pickup);
  }

  @override
  Future<void> sendOffer(AppUser actor, String pickupId, double price) async {
    _require(
      actor.role == UserRole.buyer &&
          _get(pickupId).status == PickupStatus.open,
      'This request is no longer available.',
    );
    _require(price.isFinite && price > 0, 'Enter a positive price.');
    _offers.removeWhere(
      (offer) => offer.pickupId == pickupId && offer.buyerId == actor.id,
    );
    _offers.add(
      Offer(
        id: 'O${DateTime.now().microsecondsSinceEpoch}',
        pickupId: pickupId,
        buyerId: actor.id,
        buyerName: actor.name,
        pricePerKg: price,
        verified: actor.buyerVerified,
      ),
    );
  }

  @override
  Future<void> selectOffer(AppUser actor, String offerId) async {
    final offer = _offers.firstWhere((offer) => offer.id == offerId);
    final pickup = _get(offer.pickupId);
    _require(
      actor.role == UserRole.household &&
          actor.id == pickup.ownerId &&
          pickup.status == PickupStatus.open,
      'Only the owner can choose one offer on a pending pickup.',
    );
    _replace(
      pickup.copyWith(
        status: PickupStatus.accepted,
        buyerId: offer.buyerId,
        buyerName: offer.buyerName,
        pricePerKg: offer.pricePerKg,
        buyerVerified: offer.verified,
      ),
    );
  }

  @override
  Future<void> advancePickup(AppUser actor, String pickupId) async {
    final pickup = _get(pickupId);
    _require(
      actor.role == UserRole.buyer && actor.id == pickup.buyerId,
      'Only the assigned buyer can update this pickup.',
    );
    final next = switch (pickup.status) {
      PickupStatus.accepted => PickupStatus.enRoute,
      PickupStatus.enRoute => PickupStatus.arrived,
      _ => null,
    };
    _require(next != null, 'This pickup cannot advance further.');
    _replace(pickup.copyWith(status: next));
  }

  @override
  Future<void> recordCollection(
    AppUser actor,
    String pickupId,
    double kg,
    double price,
    bool cashPaid,
  ) async {
    final pickup = _get(pickupId);
    _require(
      actor.role == UserRole.buyer &&
          actor.id == pickup.buyerId &&
          pickup.status == PickupStatus.arrived,
      'Arrive at your assigned pickup before recording collection.',
    );
    _require(
      kg.isFinite && kg > 0 && price.isFinite && price > 0 && cashPaid,
      'Confirm positive weight, price and payment in person.',
    );
    _replace(
      pickup.copyWith(
        status: PickupStatus.awaitingConfirmation,
        actualKg: kg,
        pricePerKg: price,
      ),
    );
  }

  @override
  Future<void> confirmCollection(
    AppUser actor,
    String pickupId, {
    required bool accepted,
  }) async {
    final pickup = _get(pickupId);
    _require(
      actor.role == UserRole.household &&
          actor.id == pickup.ownerId &&
          pickup.status == PickupStatus.awaitingConfirmation,
      'Only the owner can confirm a submitted collection.',
    );
    _replace(
      pickup.copyWith(
        status: accepted ? PickupStatus.completed : PickupStatus.disputed,
      ),
    );
  }

  @override
  Future<void> cancelPickup(AppUser actor, String pickupId) async {
    final pickup = _get(pickupId);
    _require(
      actor.role == UserRole.household &&
          pickup.ownerId == actor.id &&
          [PickupStatus.open, PickupStatus.accepted].contains(pickup.status),
      'This request cannot be cancelled now.',
    );
    _replace(pickup.copyWith(status: PickupStatus.cancelled));
  }

  @override
  Future<ChatMessage> sendMessage(
    AppUser actor,
    String pickupId,
    String text,
  ) async {
    final pickup = _get(pickupId);
    final participant =
        actor.id == pickup.ownerId ||
        actor.id == pickup.buyerId ||
        _offers.any(
          (offer) => offer.pickupId == pickupId && offer.buyerId == actor.id,
        );
    _require(
      participant && text.trim().isNotEmpty && text.length <= 1000,
      'Message must be between 1 and 1000 characters and sent by a participant.',
    );
    final message = ChatMessage(
      id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
      pickupId: pickupId,
      senderId: actor.id,
      text: text.trim(),
      sentAt: DateTime.now(),
    );
    _messages.add(message);
    return message;
  }
}
