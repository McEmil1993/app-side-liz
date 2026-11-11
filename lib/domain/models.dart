import 'dart:typed_data';
import 'location.dart';
import 'map_location.dart';

enum UserRole { household, buyer }

extension UserRoleLabel on UserRole {
  String get label => this == UserRole.household ? 'Household' : 'Scrap Buyer';
}

enum PickupStatus {
  open,
  accepted,
  enRoute,
  arrived,
  awaitingConfirmation,
  completed,
  cancelled,
  disputed,
}

extension PickupStatusLabel on PickupStatus {
  String get label => switch (this) {
    PickupStatus.open => 'Pending',
    PickupStatus.accepted => 'Accepted',
    PickupStatus.enRoute => 'On the way',
    PickupStatus.arrived => 'Arrived',
    PickupStatus.awaitingConfirmation => 'Confirm collection',
    PickupStatus.completed => 'Completed',
    PickupStatus.cancelled => 'Cancelled',
    PickupStatus.disputed => 'Disputed',
  };
  String get apiValue => switch (this) {
    PickupStatus.enRoute => 'en_route',
    PickupStatus.awaitingConfirmation => 'awaiting_confirmation',
    _ => name,
  };
}

class AppUser {
  final String cityMunicipality, cityMunicipalityCode, barangayCode;
  final String id, firstname, lastname, barangay;
  final String middlename, suffix, username, email, contact, streetPurok;
  final bool buyerVerified;
  final UserRole role;
  final Uint8List? avatar;
  final String verificationStatus;
  const AppUser({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.role,
    this.barangay = 'San Vicente',
    this.middlename = '',
    this.suffix = '',
    this.username = '',
    this.email = '',
    this.contact = '',
    this.streetPurok = '',
    this.buyerVerified = false,
    this.avatar,
    this.verificationStatus = 'not_submitted',
    this.cityMunicipality = 'Trinidad',
    this.cityMunicipalityCode = LocationDefaults.cityCode,
    this.barangayCode = LocationDefaults.barangayCode,
  });
  AppUser withPinAddress(GeoPin pin) => AppUser(
    id: id,
    firstname: firstname,
    lastname: lastname,
    role: role,
    middlename: middlename,
    suffix: suffix,
    username: username,
    email: email,
    contact: contact,
    buyerVerified: buyerVerified,
    avatar: avatar,
    verificationStatus: verificationStatus,
    barangay: pin.location?.barangay.name ?? barangay,
    cityMunicipality: pin.location?.city.name ?? cityMunicipality,
    cityMunicipalityCode: pin.location?.city.code ?? cityMunicipalityCode,
    barangayCode: pin.location?.barangay.code ?? barangayCode,
    streetPurok: pin.location == null ? streetPurok : pin.street,
  );
  String get name => [
    firstname,
    middlename,
    lastname,
    suffix,
  ].where((part) => part.isNotEmpty).join(' ');
  Map<String, String> get locationPayload => {
    'regions': LocationDefaults.regionCode,
    'provinces': LocationDefaults.provinceCode,
    'cities_municipalities': cityMunicipalityCode,
    'barangays': barangayCode,
  };
  MapAddress get mapAddress => MapAddress(
    street: streetPurok,
    barangay: barangay,
    city: cityMunicipality,
    barangayCode: barangayCode,
  );
}

class Pickup {
  final GeoPin? locationPin;
  MapAddress get mapAddress => MapAddress(
    street: streetPurok,
    barangay: barangay,
    city: cityMunicipality,
    barangayCode: barangayCode,
  );
  final String cityMunicipality, cityMunicipalityCode, barangayCode;
  final String id, ownerId, ownerName, category, barangay, streetPurok, notes;
  final double estimatedKg, distanceKm;
  final DateTime windowStart, windowEnd;
  final PickupStatus status;
  final String? buyerId, buyerName;
  final double? actualKg, pricePerKg;
  final bool buyerVerified;
  final Uint8List? photo;
  final String? photoUrl;
  const Pickup({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.category,
    required this.estimatedKg,
    required this.barangay,
    required this.streetPurok,
    required this.windowStart,
    required this.windowEnd,
    this.cityMunicipality = 'Trinidad',
    this.cityMunicipalityCode = LocationDefaults.cityCode,
    this.barangayCode = '',
    this.distanceKm = 1.2,
    this.status = PickupStatus.open,
    this.buyerId,
    this.buyerName,
    this.actualKg,
    this.buyerVerified = false,
    this.pricePerKg,
    this.photo,
    this.photoUrl,
    this.notes = '',
    this.locationPin,
  });
  double get amount =>
      ((actualKg ?? 0) * (pricePerKg ?? 0) * 100).round() / 100;
  Pickup copyWith({
    PickupStatus? status,
    String? buyerId,
    String? buyerName,
    double? actualKg,
    double? pricePerKg,
    bool? buyerVerified,
    GeoPin? locationPin,
  }) => Pickup(
    id: id,
    ownerId: ownerId,
    ownerName: ownerName,
    category: category,
    estimatedKg: estimatedKg,
    barangay: locationPin?.location?.barangay.name ?? barangay,
    cityMunicipality: locationPin?.location?.city.name ?? cityMunicipality,
    cityMunicipalityCode:
        locationPin?.location?.city.code ?? cityMunicipalityCode,
    barangayCode: locationPin?.location?.barangay.code ?? barangayCode,
    streetPurok: locationPin?.location == null
        ? streetPurok
        : locationPin!.street,
    windowStart: windowStart,
    windowEnd: windowEnd,
    notes: notes,
    distanceKm: distanceKm,
    status: status ?? this.status,
    buyerId: buyerId ?? this.buyerId,
    buyerName: buyerName ?? this.buyerName,
    actualKg: actualKg ?? this.actualKg,
    pricePerKg: pricePerKg ?? this.pricePerKg,
    photo: photo,
    photoUrl: photoUrl,
    buyerVerified: buyerVerified ?? this.buyerVerified,
    locationPin: locationPin ?? this.locationPin,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'household_user_id': ownerId,
    'category': category,
    'estimated_weight_kg': estimatedKg,
    'barangay': barangay,
    'regions': LocationDefaults.regionCode,
    'provinces': LocationDefaults.provinceCode,
    'cities_municipalities': cityMunicipalityCode,
    'barangays': barangayCode,
    'street_purok': streetPurok,
    'window_start': windowStart.toUtc().toIso8601String(),
    'window_end': windowEnd.toUtc().toIso8601String(),
    'status': status.apiValue,
    'assigned_buyer_user_id': buyerId,
    'actual_weight_kg': actualKg,
    'final_price_per_kg': pricePerKg,
    'notes': notes,
    if (locationPin != null) 'location_pin': locationPin!.toJson(),
  };
}

class Offer {
  final String id, pickupId, buyerId, buyerName;
  final String buyerLocation;
  final double pricePerKg;
  final bool verified;
  const Offer({
    required this.id,
    required this.pickupId,
    required this.buyerId,
    required this.buyerName,
    required this.pricePerKg,
    this.verified = true,
    this.buyerLocation = '',
  });
}

class ChatMessage {
  final String id;
  final bool pending;
  final String pickupId, senderId, text;
  final DateTime sentAt;
  const ChatMessage({
    this.id = '',
    this.pending = false,
    required this.pickupId,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> data) => ChatMessage(
    id: '${data['id']}',
    pickupId: '${data['pickup_id']}',
    senderId: '${data['sender_id']}',
    text: data['text'] as String,
    sentAt: DateTime.parse(data['sent_at'] as String).toLocal(),
  );
}

class AppNotice {
  final String title, message;
  final UserRole role;
  final String? pickupId;
  final String? announcementAudience;
  const AppNotice(
    this.title,
    this.message,
    this.role, {
    this.pickupId,
    this.announcementAudience,
  });
}
