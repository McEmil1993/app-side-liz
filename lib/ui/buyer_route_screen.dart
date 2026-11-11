import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/app_controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'pickup_detail_screen.dart';
import 'route_map.dart';
import 'widgets.dart';

class BuyerRouteScreen extends StatelessWidget {
  const BuyerRouteScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final stops = app.assigned
        .where((p) => p.status != PickupStatus.awaitingConfirmation)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Your pickup route',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Scheduled pickup stops in Bohol',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        RouteMap(
          stops: stops,
          originAddress: app.user.mapAddress,
          originPin: app.profilePin,
        ),
        const SizedBox(height: 14),
        Surface(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '${stops.length}',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                    ),
                  ),
                  const Text('Pickup stops'),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${kg(stops.fold<double>(0, (sum, p) => sum + p.estimatedKg))} kg',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                    ),
                  ),
                  const Text('Estimated scrap'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'The blue line follows mapped roads. Stop order follows your pickup schedule; confirm exact pickup pins with the household.',
          style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.5),
        ),
        const SectionTitle('Pickup stops'),
        if (stops.isEmpty)
          const EmptyState(
            'No remaining stops',
            'Accepted pickups appear here. Check Collections for records waiting for confirmation.',
          ),
        ...stops.indexed.map((entry) {
          final p = entry.$2;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.mint,
                        foregroundColor: AppColors.green,
                        child: Text('${entry.$1 + 1}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.ownerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${p.category} · ${kg(p.estimatedKg)} kg',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(p.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${p.streetPurok}, ${p.barangay}, ${p.cityMunicipality}',
                  ),
                  Text(
                    '${dateLabel(p.windowStart)} · ${windowLabel(p)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  PickupDetailScreen(pickupId: p.id),
                            ),
                          ),
                          child: const Text('View pickup'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Copy address',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text:
                                  '${p.streetPurok}, ${p.barangay}, ${p.cityMunicipality}, Bohol',
                            ),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Address copied.')),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.copy_outlined,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
