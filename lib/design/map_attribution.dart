import 'package:flutter/material.dart';

/// Kept above map overlays, always visible rather than behind trip sheets.
class MTaxiMapAttribution extends StatelessWidget {
  const MTaxiMapAttribution({super.key});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topRight,
        child: Container(
            constraints: const BoxConstraints(maxWidth: 210),
            color: Theme.of(context)
                .scaffoldBackgroundColor
                .withValues(alpha: .94),
            padding: const EdgeInsets.all(4),
            child: const Text('© OpenStreetMap contributors',
                textAlign: TextAlign.right, style: TextStyle(fontSize: 12))),
      );
}
