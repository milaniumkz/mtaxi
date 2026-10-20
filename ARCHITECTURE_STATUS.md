# Architecture Status

## Backend-Authoritative Now

These areas are server-truth in the current backend-only architecture:

- User role and capability resolution via `users.roleState`.
- Driver approval/blocking via backend user operations.
- Active driver order via `users.activeDriverOrderId`.
- Active passenger order via `users.activePassengerOrderId`.
- Order lifecycle via `orders.status`.
- Order ownership via `orders.idDriver` and `orders.idUser`.
- Driver order claiming via backend callable `acceptOrder`.
- Admin critical mutations via typed backend callables.
- Runtime settings via backend `getRuntimeSettings` / `updateRuntimeSettings`.
- Push target intent via `type + targetRole`.

Primary backend entrypoints:

- `server/src/call_router.js`
- `server/src/orders.js`
- `server/src/users.js`
- `server/src/admin.js`
- `server/src/session.js`
- `server/src/settings.js`
- `server/src/push.js`
- `server/src/maintenance.js`

Firebase is allowed only as FCM transport through `server/src/push_transport.js`.
It must not be used for Auth, Firestore, Cloud Functions, Storage, SMS, orders,
payments, chats, settings, files, or admin data.

## Compatibility-Only Now

These fields/paths still exist for compatibility, but are not intended to be
the primary source of truth:

- `users.activeMode`
- local `FFAppState.idOrder`
- local `FFAppState.idOrderDriver`
- local `FFAppState.driver`
- local `FFAppState.passenger`
- push `initialPageName`

Where compatibility is intentionally isolated:

- `lib/backend/order_state_compat.dart`
- `lib/auth/backend_auth/auth_util.dart`
- `lib/backend/backend_refs_compat.dart`
- `lib/backend/push_notifications/push_deep_link_router.dart`
- `server/src/push.js` legacy route payload fields for already shipped clients

Compatibility rules:

- `FFAppState.idOrder` and `FFAppState.idOrderDriver` are mirrors/fallbacks only.
- `FFAppState.driver` and `FFAppState.passenger` are in-memory only and are no
  longer persisted.
- `users.activeMode` is readable only for back-compat projection.
- `getUserActiveMode(...)` is a compatibility helper, not a routing authority.
- `BackendRefs.instance.doc(path)` is a local compatibility reference builder
  from `backend_refs_compat.dart`, not a network Firestore client.

## Client Routing Rules

- Driver screen access should use `UserModeResolver.canOpenDriverScreens(...)`.
- Passenger screen access should use `UserModeResolver.canOpenPassengerScreens(...)`.
- Order screen access should use backend session/order refs first.
- Active order recovery should use backend `getSessionBootstrap` and
  `getOrderDetails`.
- `getUserActiveMode(...)` is only a compatibility projection.

## Admin Mutation Rules

Use typed backend operations for critical user/order/money changes:

- `adminCreateDriver`
- `adminCreatePassenger`
- `adminTopUpDriverBalance`
- `adminUpdateDriverCity`
- `adminUpdateDriverOrderDelay`
- `adminManageOrder`
- `adminResolveWithdrawal`
- `approveDriver`
- `blockDriver`
- `unblockDriver`
- `approveVehiclePhotoDeletion`
- `rejectVehiclePhotoDeletion`

Avoid raw document writes for:

- role / roleState
- statusDriver
- blocked
- balance mutations
- withdrawal status
- driver city/order delay mutations
- active order refs

## Push Routing Rules

- Use `type + targetRole` as primary route intent.
- Treat `initialPageName` only as compatibility metadata.
- Treat `parameterData` / `parameter_data` as optional metadata only.
- Driver order notifications must include:
  - `type`
  - `targetRole`
  - `orderId`
  - `orderPath`

Legacy push compatibility helpers/fields should remain isolated in
`server/src/push.js` and `lib/backend/push_notifications/push_deep_link_router.dart`.

## Remaining Legacy Cleanup Direction

Future safe cleanup after rollout verification:

1. Remove `users.activeMode` from generated schema helpers after rollout
   confirms no dependency remains.
2. Remove `lib/backend/order_state_compat.dart` once backend user/order refs are
   guaranteed on every supported build.
3. Remove compatibility-only handling for `initialPageName` and `parameterData`
   after push rollout is stable.
4. Remove dormant legacy booleans from `FFAppState` if no generated code still
   references them.
5. Remove legacy mirror fields `idOrder` / `idOrderDriver` from backend write
   projections after the mobile compatibility window closes.
