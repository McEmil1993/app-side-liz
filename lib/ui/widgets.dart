import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../domain/models.dart';

String kg(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
String money(double value) => 'PHP ${value.toStringAsFixed(2)}';
String dateLabel(DateTime date) =>
    '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';
String clockLabel(DateTime date) =>
    '${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
String windowLabel(Pickup pickup) =>
    '${clockLabel(pickup.windowStart)} – ${clockLabel(pickup.windowEnd)}';

IconData categoryIcon(String category) => switch (category) {
  'Plastic' => Icons.water_drop_outlined,
  'Paper' => Icons.layers_outlined,
  'Cardboard' => Icons.inventory_2_outlined,
  'Metal' => Icons.recycling,
  _ => Icons.wine_bar_outlined,
};
Color categoryColor(String category) => switch (category) {
  'Plastic' => const Color(0xFFE2F2FF),
  'Paper' => const Color(0xFFF3ECDF),
  'Cardboard' => const Color(0xFFFFF0D9),
  'Metal' => const Color(0xFFE8EDF1),
  _ => const Color(0xFFE6F4EE),
};
const categories = ['Plastic', 'Paper', 'Cardboard', 'Metal', 'Glass'];

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 42});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.green,
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Icon(Icons.eco_rounded, color: Colors.white, size: size * .65),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;
  const SectionTitle(this.title, {super.key, this.action, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    ),
  );
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

class MaterialTile extends StatelessWidget {
  final String category;
  final double size;
  const MaterialTile(this.category, {super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: categoryColor(category),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(
      categoryIcon(category),
      color: AppColors.darkGreen,
      size: size * .5,
    ),
  );
}

class StatusPill extends StatelessWidget {
  final PickupStatus status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final pending =
        status == PickupStatus.open ||
        status == PickupStatus.awaitingConfirmation;
    final bad =
        status == PickupStatus.cancelled || status == PickupStatus.disputed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bad
            ? const Color(0xFFFFEEEE)
            : pending
            ? const Color(0xFFFFF3D4)
            : AppColors.mint,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: bad
              ? Colors.red.shade700
              : pending
              ? const Color(0xFF9B6500)
              : AppColors.green,
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  final String label, value;
  final IconData? icon;
  const DetailRow(this.label, this.value, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: AppColors.muted),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.inbox_outlined,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    child: Column(
      children: [
        Icon(icon, color: AppColors.green, size: 44),
        const SizedBox(height: 14),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

Future<bool> perform(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), behavior: SnackBarBehavior.floating),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
    return false;
  }
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
