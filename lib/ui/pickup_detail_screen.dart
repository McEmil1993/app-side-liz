import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'collection_screen.dart';
import 'shared_screens.dart';
import 'widgets.dart';
import 'maps/address_map.dart';
import '../domain/map_location.dart';

class PickupDetailScreen extends StatelessWidget {
  final String pickupId;
  const PickupDetailScreen({super.key, required this.pickupId});
  Future<void> _offer(
    BuildContext context,
    AppController app,
    Pickup pickup,
  ) async {
    var priceText = (pickup.pricePerKg ?? 12).toString();
    final key = GlobalKey<FormState>();
    final price = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send your offer'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${pickup.category} · ${kg(pickup.estimatedKg)} kg estimated',
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: priceText,
                onChanged: (value) => priceText = value,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price per kg',
                  prefixText: 'PHP ',
                ),
                validator: (value) {
                  final price = double.tryParse(value ?? '');
                  return price == null || !price.isFinite || price <= 0
                      ? 'Enter a valid price.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'The household chooses a buyer. This is not an automatic assignment.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(context, double.parse(priceText));
              }
            },
            child: const Text('Send offer'),
          ),
        ],
      ),
    );
    if (price != null && context.mounted) {
      await perform(
        context,
        () => app.sendOffer(pickup.id, price),
        success: 'Offer sent. Wait for household selection.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pickup = app.pickup(pickupId);
    final household = app.role == UserRole.household;
    final owner = household && pickup.ownerId == app.user.id;
    final assigned = !household && pickup.buyerId == app.user.id;
    final offers = app.offers
        .where((offer) => offer.pickupId == pickup.id)
        .toList();
    final exactAddress = owner || assigned;
    final canMessage = app.connected
        ? pickup.buyerId != null && (owner || assigned)
        : owner
        ? offers.isNotEmpty || pickup.buyerId != null
        : assigned || offers.any((offer) => offer.buyerId == app.user.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Pickup Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.green,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickup.status.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkGreen,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        pickup.status == PickupStatus.open
                            ? 'Review offers and choose your buyer.'
                            : pickup.status == PickupStatus.awaitingConfirmation
                            ? 'Waiting for household confirmation.'
                            : 'Keep track of your collection here.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.darkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: AppColors.mint,
                      child: Icon(
                        household
                            ? Icons.person_outline
                            : Icons.cottage_outlined,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            household
                                ? pickup.buyerName ?? 'Choose a buyer'
                                : pickup.ownerName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            household
                                ? pickup.buyerId == null
                                      ? 'Your pickup is visible to local buyers'
                                      : pickup.buyerVerified
                                      ? 'Verified scrap buyer'
                                      : 'Scrap buyer'
                                : 'Household',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (household && pickup.buyerVerified)
                      const Icon(
                        Icons.verified,
                        color: AppColors.green,
                        size: 21,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                DetailRow(
                  'Category',
                  pickup.category,
                  icon: categoryIcon(pickup.category),
                ),
                DetailRow('Estimated weight', '${kg(pickup.estimatedKg)} kg'),
                DetailRow(
                  'Scheduled pickup',
                  dateLabel(pickup.windowStart),
                  icon: Icons.calendar_today_outlined,
                ),
                DetailRow('Time window', windowLabel(pickup)),
                DetailRow(
                  exactAddress ? 'Pickup address' : 'Approximate area',
                  '${exactAddress ? '${pickup.streetPurok}, ' : ''}${pickup.barangay}\n${pickup.cityMunicipality}, Bohol',
                  icon: Icons.location_on_outlined,
                ),
                if (pickup.pricePerKg != null &&
                    pickup.status != PickupStatus.open)
                  DetailRow(
                    'Agreed offer',
                    '${money(pickup.pricePerKg!)} / kg',
                  ),
                if (pickup.notes.isNotEmpty) DetailRow('Notes', pickup.notes),
                if (pickup.photo != null || pickup.photoUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: pickup.photoUrl != null
                          ? Image.network(
                              pickup.photoUrl!,
                              headers: app.repository.mediaHeaders,
                              height: 170,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Photo could not load. Tap Refresh to retry.',
                                ),
                              ),
                            )
                          : Image.memory(
                              pickup.photo!,
                              height: 170,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AddressMap(
            address: exactAddress
                ? pickup.mapAddress
                : MapAddress(
                    street: '',
                    barangay: pickup.barangay,
                    city: pickup.cityMunicipality,
                    barangayCode: pickup.barangayCode,
                  ),
            savedPin: exactAddress ? pickup.locationPin : null,
            title: exactAddress ? 'Pickup map' : 'Approximate pickup area',
            onSave:
                owner &&
                    (!app.connected || pickup.status == PickupStatus.open) &&
                    [
                      PickupStatus.open,
                      PickupStatus.accepted,
                    ].contains(pickup.status)
                ? (pin) => perform(
                    context,
                    () => app.updatePickupPin(pickup.id, pin),
                    success: 'Pickup pin saved.',
                  )
                : null,
          ),
          if (owner && pickup.status == PickupStatus.open) ...[
            SectionTitle('Buyer offers (${offers.length})'),
            if (offers.isEmpty)
              const EmptyState(
                'Waiting for offers',
                'Buyers can send an offer after viewing your request.',
              )
            else
              ...offers.map(
                (offer) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              offer.verified
                                  ? Icons.verified
                                  : Icons.person_outline,
                              size: 18,
                              color: AppColors.green,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: TextButton(
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(offer.buyerName),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          offer.verified
                                              ? 'LGU verified buyer'
                                              : 'Verification pending',
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Location: ${offer.buyerLocation.isEmpty ? 'Not provided' : offer.buyerLocation}',
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Offer: ${money(offer.pricePerKg)}/kg',
                                        ),
                                        const SizedBox(height: 12),
                                        Text('Material: ${pickup.category}'),
                                        const Text(
                                          'The selected buyer will receive your pickup assignment.',
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Flexible(child: Text(offer.buyerName)),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.info_outline, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              '${money(offer.pricePerKg)}/kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Accepts this category · Available in your area',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: app.busy
                                ? null
                                : () async {
                                    final confirmed = await confirmAction(
                                      context,
                                      'Choose ${offer.buyerName}?',
                                      'Confirm this buyer for the scheduled pickup at ${money(offer.pricePerKg)} per kg.',
                                    );
                                    if (confirmed && context.mounted) {
                                      await perform(
                                        context,
                                        () => app.selectOffer(offer.id),
                                        success:
                                            'Buyer selected. Your pickup is accepted.',
                                      );
                                    }
                                  },
                            child: const Text('Select buyer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          if (!household && pickup.status == PickupStatus.open)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: FilledButton(
                onPressed: app.busy ? null : () => _offer(context, app, pickup),
                child: Text(
                  offers.any((offer) => offer.buyerId == app.user.id)
                      ? 'Update your offer'
                      : 'Send offer',
                ),
              ),
            ),
          if (canMessage)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(pickupId: pickup.id),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(household ? 'Message buyer' : 'Message household'),
              ),
            ),
          if (assigned &&
              [
                PickupStatus.accepted,
                PickupStatus.enRoute,
              ].contains(pickup.status))
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: FilledButton.icon(
                onPressed: app.busy
                    ? null
                    : () => perform(context, () => app.advance(pickup.id)),
                icon: Icon(
                  pickup.status == PickupStatus.accepted
                      ? Icons.local_shipping_outlined
                      : Icons.location_on_outlined,
                ),
                label: Text(
                  pickup.status == PickupStatus.accepted
                      ? 'Start pickup'
                      : 'Mark as arrived',
                ),
              ),
            ),
          if (assigned && pickup.status == PickupStatus.arrived)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionScreen(pickupId: pickup.id),
                  ),
                ),
                child: const Text('Record collection'),
              ),
            ),
          if (pickup.actualKg != null) ...[
            const SectionTitle('Collection record'),
            Surface(
              child: Column(
                children: [
                  DetailRow('Actual weight', '${kg(pickup.actualKg!)} kg'),
                  DetailRow('Final price', '${money(pickup.pricePerKg!)}/kg'),
                  const Divider(),
                  DetailRow('Total amount', money(pickup.amount)),
                  const Text(
                    'Cash paid directly in person',
                    style: TextStyle(fontSize: 12, color: AppColors.green),
                  ),
                ],
              ),
            ),
          ],
          if (owner && pickup.status == PickupStatus.awaitingConfirmation) ...[
            const SizedBox(height: 18),
            const Text(
              'Confirm only if the weight, agreed price and cash received are correct.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: app.busy
                  ? null
                  : () async {
                      final confirmed = await confirmAction(
                        context,
                        'Confirm collection?',
                        'I confirm the actual weight and that I received ${money(pickup.amount)} directly from the buyer.',
                      );
                      if (confirmed && context.mounted) {
                        await perform(
                          context,
                          () => app.confirm(pickup.id, true),
                          success:
                              'Collection completed. Thank you for recycling!',
                        );
                      }
                    },
              child: const Text('Confirm collection & cash received'),
            ),
            TextButton(
              onPressed: app.busy
                  ? null
                  : () async {
                      final confirmed = await confirmAction(
                        context,
                        'Report a disagreement?',
                        'This collection will be marked disputed and excluded from completed totals.',
                      );
                      if (confirmed && context.mounted) {
                        await perform(
                          context,
                          () => app.confirm(pickup.id, false),
                        );
                      }
                    },
              child: const Text(
                'Weight, price or payment is incorrect',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
          if (owner &&
              [
                PickupStatus.open,
                PickupStatus.accepted,
              ].contains(pickup.status))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton(
                onPressed: app.busy
                    ? null
                    : () async {
                        final confirmed = await confirmAction(
                          context,
                          'Cancel pickup?',
                          'This request will no longer be available for collection.',
                        );
                        if (confirmed && context.mounted) {
                          await perform(context, () => app.cancel(pickup.id));
                        }
                      },
                child: const Text(
                  'Cancel this pickup request',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          const SizedBox(height: 18),
          const Text(
            'Sample data · Payment happens in person',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
