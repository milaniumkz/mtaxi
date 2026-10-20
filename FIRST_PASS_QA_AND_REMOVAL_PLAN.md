# First Pass QA And Removal Plan

## First 5 scenarios to verify manually

### 1. Race: two drivers, one order

Check first:

- passenger creates one order
- two drivers open the same order
- both tap `Взять заказ`

Pass condition:

- one driver wins
- second driver sees `Заказ взял другой водитель`
- second driver stays in driver feed
- no white screen
- no passenger redirect

### 2. Driver push routing

Check first:

- app in foreground
- app in background
- app reopened from push tap

Pass condition:

- driver push opens driver-safe route
- never opens passenger mode
- malformed push does not crash

### 3. Logout -> login

Check first for passenger and driver:

- login
- logout
- immediate login again

Pass condition:

- first attempt works
- no stale order
- no stale role/mode

### 4. Passenger active order restore

Check first:

- create order
- kill app
- reopen app
- complete/cancel/expire order

Pass condition:

- order restores correctly
- terminal state clears waiting screen

### 5. Admin typed mutations

Check first:

- top up driver balance
- update driver city
- block/unblock

Pass condition:

- balance changes only balance fields
- city update does not corrupt role/mode
- block/unblock does not corrupt unrelated fields

## First 3 legacy removals after green QA

### 1. Remove `users.activeMode` reads

Targets:

- `lib/backend/schema/users_record.dart`
- compatibility references around `getUserActiveMode(...)`

Prerequisite:

- no manual issue with role restore or routing

### 2. Remove local order mirror fallback layer

Targets:

- `lib/backend/order_state_compat.dart`
- fallback usage of `FFAppState.idOrder`
- fallback usage of `FFAppState.idOrderDriver`

Prerequisite:

- all supported builds reliably use backend user-doc refs

### 3. Remove legacy push route metadata handling

Targets:

- `initialPageName`
- `initial_page_name`
- `parameterData`
- `parameter_data`

Prerequisite:

- push routing stable on production build

## Recommended order

1. Run the 5 manual QA scenarios above
2. Watch production for regressions
3. Remove legacy layer in the 3 phases above
