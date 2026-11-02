import 'package:flutter/material.dart';
import 'mtaxi_theme.dart';
import 'mtaxi_icon.dart';

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
      Widget card(String type, String title, String description, String icon) {
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
                    child: Tooltip(
                        message: description,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(children: [
                            Container(
                                width: 32,
                                height: 32,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                    color: selected
                                        ? MTaxiDesign.gold
                                        : (dark
                                            ? scheme.surfaceContainerHighest
                                            : Colors.white),
                                    borderRadius: BorderRadius.circular(9)),
                                child: MTaxiIcon(icon,
                                    size: 26,
                                    color: selected
                                        ? MTaxiDesign.ink
                                        : scheme.onSurface)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(title,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurface))),
                            if (selected) ...[
                              const SizedBox(width: 4),
                              Container(
                                  width: 16,
                                  height: 16,
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: dark
                                          ? MTaxiDesign.gold
                                          : MTaxiDesign.ink),
                                  child: MTaxiIcon('check',
                                      size: 12,
                                      color: dark
                                          ? MTaxiDesign.ink
                                          : Colors.white)),
                            ],
                          ]),
                        )),
                  ),
                )));
      }

      return Wrap(spacing: 12, runSpacing: 12, children: [
        card('taxi', taxiLabel, taxiDescription, 'car'),
        card('delivery', deliveryLabel, deliveryDescription, 'parcel'),
      ]);
    });
  }
}
