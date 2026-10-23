import 'mtaxi_icon.dart';
import 'package:flutter/material.dart';
import '/flutter_flow/internationalization.dart';
import 'mtaxi_theme.dart';

class MTaxiBottomNavigation extends StatelessWidget {
  const MTaxiBottomNavigation(
      {super.key,
      required this.index,
      required this.driver,
      required this.onTap});
  final int index;
  final bool driver;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    final labels = [
      driver ? tr('Заказы', 'Тапсырыстар') : tr('Поездка', 'Сапар'),
      driver ? tr('Счёт', 'Шот') : tr('Кошелёк', 'Әмиян'),
      tr('История', 'Тарих'),
      tr('Профиль', 'Профиль')
    ];
    final icons = [driver ? 'car' : 'route', 'wallet', 'clock', 'user'];
    return Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor))),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                      child: Semantics(
                          selected: index == i,
                          button: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => onTap(i),
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: index == i
                                                  ? MTaxiDesign.gold
                                                      .withValues(alpha: .28)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: MTaxiIcon(icons[i])),
                                      const SizedBox(height: 4),
                                      Text(labels[i],
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: index == i
                                                  ? FontWeight.w700
                                                  : FontWeight.w400)),
                                    ])),
                          )))
              ]),
            )));
  }
}

/// Offstage tabs retain state but do not run active-screen GPS/navigation work.
class MTaxiTabActivity extends InheritedWidget {
  const MTaxiTabActivity(
      {super.key, required this.active, required super.child});
  final bool active;
  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MTaxiTabActivity>()?.active ??
      true;
  @override
  bool updateShouldNotify(MTaxiTabActivity oldWidget) =>
      oldWidget.active != active;
}
