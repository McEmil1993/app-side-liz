import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'pickup_detail_screen.dart';
import 'widgets.dart';
import 'maps/address_map.dart';

class HouseholdHome extends StatelessWidget {
  final VoidCallback onPost, onPickups;
  const HouseholdHome({
    super.key,
    required this.onPost,
    required this.onPickups,
  });
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final active = app.ownPickups
        .where(
          (p) => ![
            PickupStatus.completed,
            PickupStatus.cancelled,
            PickupStatus.disputed,
          ].contains(p.status),
        )
        .toList();
    final totalKg = app.history.fold<double>(
      0,
      (sum, pickup) => sum + (pickup.actualKg ?? 0),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${app.user.firstname}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Small steps. A cleaner community.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cottage_outlined,
                size: 34,
                color: AppColors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        InkWell(
          onTap: onPost,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00A166), AppColors.green],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(20),
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFF82E3B8),
                  child: Icon(Icons.add, color: AppColors.darkGreen, size: 28),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post Scrap',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Request a pickup from nearby buyers',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
        const SectionTitle('Your pickup location'),
        AddressMap(
          userLocation: true,
          address: app.user.mapAddress,
          savedPin: app.profilePin,
          onSave: app.saveProfilePin,
        ),
        SectionTitle('Active pickups', action: 'View all', onTap: onPickups),
        if (active.isEmpty)
          const EmptyState(
            'Ready to recycle?',
            'Post your first recyclable materials.',
          )
        else
          ...active
              .take(2)
              .map(
                (pickup) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PickupCard(pickup: pickup),
                ),
              ),
        const SectionTitle('Recyclable categories'),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: app.catalog.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => InkWell(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MaterialTile(app.catalog[i]),
                      const SizedBox(height: 14),
                      Text(
                        app.catalog[i],
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Clean and separate your recyclables. Actual price and weight are agreed with the buyer during collection.',
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 80,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: categoryColor(app.catalog[i]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      categoryIcon(app.catalog[i]),
                      size: 35,
                      color: AppColors.darkGreen,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      app.catalog[i],
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SectionTitle('Your recycling impact'),
        Surface(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.eco_outlined, color: AppColors.green),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${kg(totalKg)} kg',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Text(
                      'Confirmed recyclables collected',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.trending_up, color: AppColors.green),
            ],
          ),
        ),
      ],
    );
  }
}

class PickupCard extends StatelessWidget {
  final Pickup pickup;
  final bool marketplace;
  const PickupCard({super.key, required this.pickup, this.marketplace = false});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PickupDetailScreen(pickupId: pickup.id),
      ),
    ),
    borderRadius: BorderRadius.circular(18),
    child: Surface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaterialTile(pickup.category, size: 60),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pickup.category,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (marketplace)
                      Text(
                        '${pickup.distanceKm} km',
                        style: const TextStyle(
                          color: Color(0xFF287BDD),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${kg(pickup.estimatedKg)} kg ${marketplace ? 'estimated' : '· ${pickup.buyerName ?? 'Awaiting offers'}'}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '${pickup.barangay}, ${pickup.cityMunicipality}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${dateLabel(pickup.windowStart)} · ${clockLabel(pickup.windowStart)}',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                if (marketplace)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PickupDetailScreen(pickupId: pickup.id),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                      ),
                      child: const Text('View / Send offer'),
                    ),
                  )
                else
                  StatusPill(pickup.status),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class PickupsScreen extends StatefulWidget {
  const PickupsScreen({super.key});
  @override
  State<PickupsScreen> createState() => _PickupsScreenState();
}

class _PickupsScreenState extends State<PickupsScreen> {
  bool history = false;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.ownPickups
        .where(
          (p) =>
              history ==
              [
                PickupStatus.completed,
                PickupStatus.cancelled,
                PickupStatus.disputed,
              ].contains(p.status),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('My pickups', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Active requests')),
            ButtonSegment(value: true, label: Text('History')),
          ],
          selected: {history},
          onSelectionChanged: (value) => setState(() => history = value.first),
        ),
        const SizedBox(height: 20),
        if (items.isEmpty)
          const EmptyState(
            'No pickups here yet',
            'New requests and confirmed collections will appear here.',
          )
        else
          ...items.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PickupCard(pickup: p),
            ),
          ),
      ],
    );
  }
}

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String selected = 'All', search = '';
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.marketplace
        .where(
          (p) =>
              (selected == 'All' || selected == p.category) &&
              '${p.category} ${p.barangay} ${p.cityMunicipality}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Nearby scrap',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const Icon(Icons.tune, size: 22, color: AppColors.green),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Find your next collection in Bohol.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        if (app.connected && !app.user.buyerVerified) ...[
          const SizedBox(height: 16),
          const Surface(
            child: Text(
              'Complete buyer verification in Profile. An LGU administrator must approve your documents before you can browse and send offers.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ],
        const SizedBox(height: 18),
        TextField(
          onChanged: (value) => setState(() => search = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search materials or barangay',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['All', ...app.catalog]
                .map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: selected == category,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => selected = category),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, size: 13, color: AppColors.muted),
            SizedBox(width: 5),
            Text(
              'Approximate area only · Sample distances',
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const EmptyState(
            'No matching requests',
            'Try another category or search.',
          )
        else
          ...items.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PickupCard(pickup: p, marketplace: true),
            ),
          ),
      ],
    );
  }
}

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'A little care goes a long way.',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Make your next pickup easier.',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 20),
      ...const [
        (
          'Rinse, then recycle',
          'Empty and rinse bottles and cans. Let them dry before storing.',
          Icons.water_drop_outlined,
        ),
        (
          'Keep paper dry',
          'Flatten cardboard and keep paper away from food and moisture.',
          Icons.inventory_2_outlined,
        ),
        (
          'Separate your materials',
          'Group plastic, paper, metal and glass before the buyer arrives.',
          Icons.recycling,
        ),
        (
          'Agree before collection',
          'Estimated weight is a guide. Check actual weight and the final price together.',
          Icons.handshake_outlined,
        ),
      ].map(
        (tip) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Surface(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(tip.$3, color: AppColors.green, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.$1,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tip.$2,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
