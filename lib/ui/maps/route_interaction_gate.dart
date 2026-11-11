import 'package:flutter/widgets.dart';

/// Embedded browser content must yield input while another route covers it.
class RouteInteractionGate extends StatelessWidget {
  final Widget Function(BuildContext context, bool interactive) builder;
  const RouteInteractionGate({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final animation = route?.secondaryAnimation;
    if (animation == null) return builder(context, route?.isCurrent ?? true);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) =>
          builder(context, route!.isCurrent && animation.isDismissed),
    );
  }
}
