import '/admin/admin_utils.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/order_state_compat.dart';

class PushRouteDecision {
  const PushRouteDecision({
    required this.routeName,
    this.reason = '',
    this.allowed = true,
  });

  final String routeName;
  final String reason;
  final bool allowed;
}

class PushDeepLinkRouter {
  static const String orderAvailableType = 'ORDER_AVAILABLE';
  static const String orderStatusChangedType = 'ORDER_STATUS_CHANGED';
  static const String orderCancelledType = 'ORDER_CANCELLED';
  static const String targetDriver = 'driver';
  static const String targetPassenger = 'passenger';
  static const String targetAdmin = 'admin';
  static const String safeDriverFallbackRoute = 'homeDriver';
  static const String safePassengerFallbackRoute = 'HomePage';
  static const String passengerOrderRoute = 'meOrder';
  static const String passengerSupportChatRoute = 'supportChat';
  static const String safeAdminFallbackRoute = 'adminHome';

  static const Set<String> _allowedDriverRoutes = {
    'homeDriver',
    'homeDriverOrder',
  };
  static const Set<String> _allowedAdminRoutes = {
    'adminHome',
    'adminSupportChats',
    'adminSupportChat',
    'adminNotifications',
    'adminDriverStats',
    'adminCollection',
  };

  static bool validatePayload(Map<String, dynamic> payload) {
    final type = (payload['type'] ?? '').toString().trim();
    final targetRole = (payload['targetRole'] ?? '').toString().trim();
    final routeName = (payload['initialPageName'] ?? '').toString().trim();
    return type.isNotEmpty || targetRole.isNotEmpty || routeName.isNotEmpty;
  }

  static bool guardRole(
    String targetRole,
    UsersRecord? userDoc,
    String? resolvedMode,
  ) {
    final normalizedTarget = targetRole.trim().toLowerCase();
    if (normalizedTarget.isEmpty) {
      return true;
    }
    if (normalizedTarget == targetDriver) {
      return UserModeResolver.canOpenDriverScreens(userDoc);
    }
    if (normalizedTarget == targetAdmin) {
      return resolvedMode == 'admin' || isAdminUser(userDoc);
    }
    if (normalizedTarget == targetPassenger) {
      return UserModeResolver.canOpenPassengerScreens(userDoc);
    }
    return true;
  }

  static String _canonicalRouteName(Map<String, dynamic> payload) {
    final type = (payload['type'] ?? '').toString().trim().toUpperCase();
    final targetRole =
        (payload['targetRole'] ?? '').toString().trim().toLowerCase();
    final routeName = (payload['initialPageName'] ?? '').toString().trim();

    if (targetRole == targetDriver && type == orderAvailableType) {
      return safeDriverFallbackRoute;
    }
    if (targetRole == targetPassenger &&
        (type == orderStatusChangedType || type == orderCancelledType)) {
      return passengerOrderRoute;
    }
    if (targetRole == targetPassenger && type == 'SUPPORT_CHAT_MESSAGE') {
      return passengerSupportChatRoute;
    }
    if (targetRole == targetPassenger) {
      return routeName.isNotEmpty ? routeName : safePassengerFallbackRoute;
    }
    if (targetRole == targetAdmin) {
      return _allowedAdminRoutes.contains(routeName)
          ? routeName
          : safeAdminFallbackRoute;
    }
    return routeName;
  }

  static PushRouteDecision resolveTargetRoute(
    Map<String, dynamic> payload,
    UsersRecord? userDoc,
    String? resolvedMode,
  ) {
    final targetRole = (payload['targetRole'] ?? '').toString().trim();
    final type = (payload['type'] ?? '').toString().trim().toUpperCase();
    final orderStatus =
        int.tryParse((payload['orderStatus'] ?? '').toString().trim());
    if (!guardRole(targetRole, userDoc, resolvedMode)) {
      if (targetRole.toLowerCase() == targetDriver) {
        return const PushRouteDecision(
          routeName: safeDriverFallbackRoute,
          reason: 'guarded_driver_fallback',
          allowed: false,
        );
      }
      if (targetRole.toLowerCase() == targetPassenger) {
        return const PushRouteDecision(
          routeName: safePassengerFallbackRoute,
          reason: 'guarded_passenger_fallback',
          allowed: false,
        );
      }
      return const PushRouteDecision(
        routeName: safeAdminFallbackRoute,
        reason: 'guard_failed',
        allowed: false,
      );
    }

    final routeName = _canonicalRouteName(payload);
    final activeDriverOrderRef = getEffectiveDriverOrderRef(userDoc);
    final activePassengerOrderRef = getEffectivePassengerOrderRef(userDoc);
    if (targetRole.toLowerCase() == targetDriver) {
      final shouldOpenDriverActiveOrder =
          activeDriverOrderRef != null &&
              type != orderCancelledType &&
              (orderStatus == null || orderStatus < 5);
      if (shouldOpenDriverActiveOrder) {
        return const PushRouteDecision(
          routeName: 'homeDriverOrder',
          reason: 'driver_active_order_route',
        );
      }
      if (_allowedDriverRoutes.contains(routeName)) {
        return PushRouteDecision(routeName: routeName);
      }
      return const PushRouteDecision(
        routeName: safeDriverFallbackRoute,
        reason: 'driver_safe_fallback',
      );
    }

    if (targetRole.toLowerCase() == targetAdmin) {
      if (_allowedAdminRoutes.contains(routeName)) {
        return PushRouteDecision(routeName: routeName);
      }
      return const PushRouteDecision(
        routeName: safeAdminFallbackRoute,
        reason: 'admin_safe_fallback',
      );
    }

    if (targetRole.toLowerCase() == targetPassenger) {
      final shouldOpenPassengerActiveOrder =
          activePassengerOrderRef != null &&
              type != orderCancelledType &&
              (orderStatus == null || orderStatus < 5);
      if (shouldOpenPassengerActiveOrder) {
        return const PushRouteDecision(
          routeName: passengerOrderRoute,
          reason: 'passenger_active_order_route',
        );
      }
      if (routeName == passengerOrderRoute ||
          routeName == passengerSupportChatRoute ||
          routeName == safePassengerFallbackRoute) {
        return PushRouteDecision(routeName: routeName);
      }
      return const PushRouteDecision(
        routeName: safePassengerFallbackRoute,
        reason: 'passenger_safe_fallback',
      );
    }

    if (routeName.isNotEmpty) {
      return PushRouteDecision(routeName: routeName);
    }

    return const PushRouteDecision(
      routeName: safePassengerFallbackRoute,
      reason: 'unknown_route_fallback',
    );
  }
}
