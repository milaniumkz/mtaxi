import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The licensed handoff SVGs, rendered natively; no remote font or icon fetch.
class MTaxiIcon extends StatelessWidget {
  const MTaxiIcon(this.name, {super.key, this.size = 24, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
      'assets/design/icons/$name.svg',
      width: size,
      height: size,
      excludeFromSemantics: true,
      colorFilter: ColorFilter.mode(
          color ?? Theme.of(context).colorScheme.onSurface, BlendMode.srcIn));
}

class MTaxiDestinationLine extends StatelessWidget {
  const MTaxiDestinationLine(this.address, {super.key});
  final String address;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const MTaxiIcon('arrow', size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(address))
      ]);
}
