import 'package:flutter_test/flutter_test.dart';
import 'package:mtaxi/backend/push_notifications/push_deep_link_router.dart';
import 'package:mtaxi/driver/home_driver/home_driver_widget.dart';
import 'package:mtaxi/driver/home_driver_order/home_driver_order_widget.dart';

void main() {
  test('driver available-order push is guarded without approved driver user', () {
    final decision = PushDeepLinkRouter.resolveTargetRoute(
      {
        'type': 'ORDER_AVAILABLE',
        'targetRole': 'driver',
        'initialPageName': HomeDriverOrderWidget.routeName,
      },
      null,
      'driver',
    );

    expect(decision.routeName, HomeDriverWidget.routeName);
    expect(decision.allowed, isFalse);
    expect(decision.reason, 'guarded_driver_fallback');
  });

  test('invalid driver route falls back to safe driver feed', () {
    final decision = PushDeepLinkRouter.resolveTargetRoute(
      {
        'type': 'ORDER_AVAILABLE',
        'targetRole': 'driver',
        'initialPageName': 'HomePage',
      },
      null,
      'driver',
    );

    expect(decision.routeName, HomeDriverWidget.routeName);
    expect(decision.reason, 'guarded_driver_fallback');
  });

  test('driver payload never opens passenger route for passenger mode', () {
    final decision = PushDeepLinkRouter.resolveTargetRoute(
      {
        'type': 'ORDER_AVAILABLE',
        'targetRole': 'driver',
        'initialPageName': HomeDriverOrderWidget.routeName,
      },
      null,
      'passenger',
    );

    expect(decision.routeName, HomeDriverWidget.routeName);
    expect(decision.allowed, isFalse);
    expect(decision.reason, 'guarded_driver_fallback');
  });

  test('missing payload validation rejects empty push', () {
    expect(PushDeepLinkRouter.validatePayload(const {}), isFalse);
  });
}
