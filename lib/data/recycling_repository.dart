import '../domain/models.dart';
import '../domain/map_location.dart';

/// UI depends on this contract, never directly on fixtures or a future HTTP client.
/// In production, actor identity must come from server-side authentication.
abstract class RecyclingRepository {
  bool get remote => false;
  List<String> get availableCategories => const [
    'Plastic',
    'Paper',
    'Cardboard',
    'Metal',
    'Glass',
  ];
  List<AppNotice> get remoteNotices => const [];
  Map<String, String> get mediaHeaders => const {};
  Future<List<Pickup>> loadPickups();
  Future<List<Offer>> loadOffers();
  Future<List<ChatMessage>> loadMessages();
  Future<void> publish(AppUser actor, Pickup pickup);
  Future<void> sendOffer(AppUser actor, String pickupId, double price);
  Future<void> selectOffer(AppUser actor, String offerId);
  Future<void> advancePickup(AppUser actor, String pickupId);
  Future<void> recordCollection(
    AppUser actor,
    String pickupId,
    double kg,
    double price,
    bool cashPaid,
  );
  Future<void> confirmCollection(
    AppUser actor,
    String pickupId, {
    required bool accepted,
  });
  Future<void> cancelPickup(AppUser actor, String pickupId);
  Future<ChatMessage> sendMessage(AppUser actor, String pickupId, String text);
  Future<void> updateLocationPin(AppUser actor, String pickupId, GeoPin pin);
}
