# Migration Notes: Role And Order State

## Goal

This project is moving from mixed client/local state toward backend-authoritative
role and active-order state.

## Backend Source Of Truth

Use these backend fields as authoritative:

- `users.roleState`
- `users.statusDriver`
- `users.blocked`
- `users.activeOrderRef`
- `users.activePassengerOrderRef`

Order ownership and lifecycle are authoritative in:

- `order.idDriver`
- `order.idUser`
- `order.status`

## Legacy Compatibility Fields

These fields are now compatibility-only and should not be treated as source of truth:

- `users.activeMode`
- local `FFAppState.idOrder`
- local `FFAppState.idOrderDriver`
- local `FFAppState.driver`
- local `FFAppState.passenger`

Current behavior:

- `FFAppState.idOrder` and `FFAppState.idOrderDriver` are mirrors only.
- `FFAppState.driver` and `FFAppState.passenger` are no longer persisted.
- `users.activeMode` is still readable for backward compatibility, but routing and
  access decisions should use `roleState`.

## Client Rules

- Resolve role/mode through `UserModeResolver`.
- Do not infer role from stale local booleans.
- Do not open driver/passenger order screens based only on `FFAppState`.
- Always prefer backend refs from the current user document.

## Admin Rules

Do not mutate critical user fields through raw document writes when a typed
operation exists.

Typed operations now cover:

- `adminCreateDriver`
- `adminTopUpDriverBalance`
- `adminUpdateDriverCity`
- `approveDriver`
- `blockDriver`
- `unblockDriver`

## Push Routing Rules

- Push routing should rely on `type + targetRole` first.
- `initialPageName` is compatibility metadata, not the primary route decision input.
- Driver order push payloads should always include:
  - `type`
  - `targetRole`
  - `orderId`
  - `orderPath`

## Cleanup Direction

Next safe cleanup steps after rollout verification:

1. Stop writing `users.activeMode` anywhere new.
2. Remove remaining code paths that navigate from raw `initialPageName`.
3. After production stabilization, remove reads of `FFAppState.driver/passenger`.
4. After production stabilization, remove fallback reads from local legacy order refs
   where backend user-doc refs are already guaranteed.
