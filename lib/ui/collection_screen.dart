import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'widgets.dart';

class CollectionScreen extends StatefulWidget {
  final String pickupId;
  const CollectionScreen({super.key, required this.pickupId});
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final form = GlobalKey<FormState>();
  final weight = TextEditingController(), price = TextEditingController();
  bool paid = false, initialized = false;
  @override
  void dispose() {
    weight.dispose();
    price.dispose();
    super.dispose();
  }

  double get total =>
      (double.tryParse(weight.text) ?? 0) * (double.tryParse(price.text) ?? 0);
  String? positive(String? value) {
    final n = double.tryParse(value ?? '');
    return n == null || !n.isFinite || n <= 0 || n > 100000
        ? 'Enter a positive amount below 100,000.'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        pickup = AppScope.of(context).pickup(widget.pickupId);
    if (!initialized) {
      weight.text = kg(pickup.estimatedKg);
      price.text = (pickup.pricePerKg ?? 12).toString();
      initialized = true;
    }
    final allowed =
        app.role == UserRole.buyer &&
        pickup.buyerId == app.user.id &&
        pickup.status == PickupStatus.arrived;
    return Scaffold(
      appBar: AppBar(title: const Text('Record Collection')),
      body: !allowed
          ? const EmptyState(
              'Collection unavailable',
              'Only the assigned buyer can record an arrived pickup.',
            )
          : Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Surface(
                    child: Row(
                      children: [
                        MaterialTile(pickup.category, size: 80),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pickup.category,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'From: ${pickup.ownerName}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pickup.barangay,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Inspect, weigh, and agree together.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Record what was actually collected, not the estimate.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: weight,
                    decoration: const InputDecoration(
                      labelText: 'Actual weight',
                      suffixText: 'kg',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: positive,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: price,
                    decoration: const InputDecoration(
                      labelText: 'Agreed price',
                      suffixText: 'PHP/kg',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: positive,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total amount',
                            style: TextStyle(
                              color: AppColors.darkGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          total.isFinite ? money(total) : '—',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment method',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  const Surface(
                    child: Row(
                      children: [
                        Icon(Icons.payments_outlined, color: AppColors.green),
                        SizedBox(width: 12),
                        Text('Cash paid in person'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: paid,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'I paid the agreed amount directly to the household.',
                      style: TextStyle(fontSize: 12),
                    ),
                    onChanged: (value) => setState(() => paid = value!),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: app.busy
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            if (!paid) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Confirm cash payment before submitting.',
                                  ),
                                ),
                              );
                              return;
                            }
                            final ok = await perform(
                              context,
                              () => app.collect(
                                pickup.id,
                                double.parse(weight.text),
                                double.parse(price.text),
                                paid,
                              ),
                              success:
                                  'Collection submitted for household confirmation.',
                            );
                            if (ok && context.mounted) Navigator.pop(context);
                          },
                    child: Text(
                      app.busy
                          ? 'Submitting…'
                          : 'Request household confirmation',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
