import 'package:flutter/material.dart';

/// Collapses the map together with its controls, preserving the current draft.
class MapVisibility extends StatefulWidget {
  final Widget header, summary, child;
  final bool initiallyExpanded;
  const MapVisibility({
    super.key,
    required this.header,
    required this.summary,
    required this.child,
    this.initiallyExpanded = false,
  });
  @override
  State<MapVisibility> createState() => _MapVisibilityState();
}

class _MapVisibilityState extends State<MapVisibility> {
  late bool visible = widget.initiallyExpanded;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: widget.header),
          IconButton(
            tooltip: visible ? 'Hide map' : 'Show map',
            onPressed: () => setState(() => visible = !visible),
            icon: Icon(
              visible ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            ),
          ),
        ],
      ),
      widget.summary,
      Visibility(visible: visible, maintainState: true, child: widget.child),
    ],
  );
}
