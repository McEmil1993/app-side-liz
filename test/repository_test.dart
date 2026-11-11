import 'package:easy_scrap/data/demo_recycling_repository.dart';
import 'package:easy_scrap/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const household = AppUser(
    id: 'h1',
    firstname: 'Juan',
    lastname: 'Santos',
    role: UserRole.household,
  );
  const buyer = AppUser(
    id: 'b1',
    firstname: 'Mang',
    lastname: 'Ben',
    role: UserRole.buyer,
  );
  const stranger = AppUser(
    id: 'b9',
    firstname: 'Other',
    lastname: 'Buyer',
    role: UserRole.buyer,
  );
  late DemoRecyclingRepository repo;
  setUp(() => repo = DemoRecyclingRepository());
  Future<Pickup> pickup(String id) async =>
      (await repo.loadPickups()).firstWhere((p) => p.id == id);

  test(
    'Offer selection assigns only one buyer; household confirms cash and weight',
    () async {
      await repo.sendOffer(buyer, 'P101', 12.5);
      final offer = (await repo.loadOffers()).firstWhere(
        (o) => o.pickupId == 'P101' && o.buyerId == buyer.id,
      );
      await repo.selectOffer(household, offer.id);
      expect((await pickup('P101')).buyerId, buyer.id);
      await expectLater(repo.selectOffer(household, 'O2'), throwsStateError);
      await expectLater(repo.advancePickup(stranger, 'P101'), throwsStateError);
      await expectLater(
        repo.recordCollection(buyer, 'P101', 8, 12.5, true),
        throwsStateError,
      );
      await repo.advancePickup(buyer, 'P101');
      await repo.advancePickup(buyer, 'P101');
      await expectLater(
        repo.recordCollection(buyer, 'P101', double.nan, 12.5, true),
        throwsStateError,
      );
      await expectLater(
        repo.recordCollection(buyer, 'P101', 7.5, 12.5, false),
        throwsStateError,
      );
      await repo.recordCollection(buyer, 'P101', 7.5, 12.5, true);
      expect((await pickup('P101')).status, PickupStatus.awaitingConfirmation);
      expect((await pickup('P101')).amount, 93.75);
      await expectLater(
        repo.confirmCollection(buyer, 'P101', accepted: true),
        throwsStateError,
      );
      await repo.confirmCollection(household, 'P101', accepted: true);
      expect((await pickup('P101')).status, PickupStatus.completed);
      await expectLater(repo.cancelPickup(household, 'P101'), throwsStateError);
    },
  );

  test(
    'Cancellation blocks offers and unauthorized household actions',
    () async {
      await expectLater(repo.cancelPickup(buyer, 'P101'), throwsStateError);
      await repo.cancelPickup(household, 'P101');
      await expectLater(repo.sendOffer(buyer, 'P101', 12), throwsStateError);
      await expectLater(repo.advancePickup(buyer, 'P101'), throwsStateError);
    },
  );

  test(
    'Disputed collection is not completed; unrelated buyer cannot message',
    () async {
      await repo.advancePickup(buyer, 'P102');
      await repo.advancePickup(buyer, 'P102');
      await repo.recordCollection(buyer, 'P102', 5, 8, true);
      await repo.confirmCollection(household, 'P102', accepted: false);
      expect((await pickup('P102')).status, PickupStatus.disputed);
      await expectLater(
        repo.sendMessage(stranger, 'P102', 'Hello'),
        throwsStateError,
      );
      await repo.sendMessage(household, 'P102', 'Please check the scale.');
      expect((await repo.loadMessages()).last.senderId, household.id);
    },
  );
}
