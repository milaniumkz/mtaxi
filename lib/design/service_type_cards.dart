import 'package:flutter/material.dart';
import 'mtaxi_theme.dart';

class ServiceTypeCards extends StatelessWidget {
  const ServiceTypeCards(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.taxiLabel,
      required this.deliveryLabel,
      required this.taxiDescription,
      required this.deliveryDescription});
  final String value;
  final ValueChanged<String> onChanged;
  final String taxiLabel, deliveryLabel, taxiDescription, deliveryDescription;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < 340 &&
          MediaQuery.textScalerOf(context).scale(16) > 24;
      final width =
          stacked ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
      Widget card(
          String type, String title, String description, IconData icon) {
        final selected = value == type;
        return SizedBox(
            width: width,
            child: Semantics(
                button: true,
                selected: selected,
                child: Material(
                  color: selected
                      ? (dark
                          ? const Color(0xFF413925)
                          : const Color(0xFFFBF0D7))
                      : (dark ? scheme.surface : MTaxiDesign.surface),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                          color: selected
                              ? MTaxiDesign.gold
                              : scheme.outlineVariant.withValues(alpha: .5),
                          width: selected ? 1.5 : 1)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                      key: ValueKey('service-card-$type'),
                      onTap: () => onChanged(type),
                      child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(children: [
                                  Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                          color: selected
                                              ? MTaxiDesign.gold
                                              : (dark
                                                  ? scheme
                                                      .surfaceContainerHighest
                                                  : Colors.white),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Icon(icon,
                                          color: selected
                                              ? MTaxiDesign.ink
                                              : scheme.onSurface,
                                          size: 26)),
                                  const Spacer(),
                                  if (selected)
                                    Icon(Icons.check_circle_rounded,
                                        color: dark
                                            ? MTaxiDesign.gold
                                            : MTaxiDesign.ink,
                                        size: 20),
                                ]),
                                const SizedBox(height: 10),
                                Text(title,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurface)),
                                const SizedBox(height: 3),
                                Text(description,
                                    style: TextStyle(
                                        fontSize: 12,
                                        height: 1.3,
                                        color: scheme.onSurfaceVariant)),
                              ]))),
                )));
      }

      return Wrap(spacing: 12, runSpacing: 12, children: [
        card('taxi', taxiLabel, taxiDescription, Icons.local_taxi_rounded),
        card('delivery', deliveryLabel, deliveryDescription,
            Icons.inventory_2_outlined),
      ]);
    });
  }
}
