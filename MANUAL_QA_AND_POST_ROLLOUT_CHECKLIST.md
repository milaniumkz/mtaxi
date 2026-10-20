# Manual QA And Post-Rollout Checklist

## Goal

This checklist is for the first manual validation pass after the current
architecture refactor. It is split into:

1. Critical manual QA scenarios
2. Rollout verification signals
3. Safe post-rollout legacy removals

The intent is:

- first verify that the new backend-authoritative model works on devices
- then remove compatibility-only code in a controlled order

## Critical manual QA scenarios

### 1. Order race: winner / loser

Test with two driver devices and one passenger:

- Create one open order from passenger
- Open the same order on two drivers
- Tap `Взять заказ` nearly simultaneously

Expected:

- only one driver gets the order
- second driver sees `Заказ взял другой водитель`
- second driver stays on driver feed
- no white screen
- no redirect to passenger mode
- no active order screen for loser

### 2. Driver role consistency

For one approved driver account:

- login
- switch between driver-related screens
- receive driver push
- open app from cold start
- logout and login again

Expected:

- driver stays in driver-capable state
- driver push never opens passenger flow
- post-login routing is consistent

### 3. Passenger order restore

For one passenger account:

- create order
- kill app
- reopen app
- let order move through statuses
- cancel / complete / expire

Expected:

- app restores active passenger order correctly
- completed/cancelled/expired orders do not stay hanging
- no stale waiting screen after terminal states

### 4. Push routing

Validate separately:

- driver order push
- passenger order status push
- admin/support broadcast push

Expected:

- route decision follows `type + targetRole`
- malformed/partial payload does not crash app
- safe fallback route opens instead of blank screen

### 5. Logout / login

For passenger and driver:

- login
- logout
- immediately login again
- repeat multiple times

Expected:

- first login attempt works
- no stale order state
- no stale role/mode state

### 6. Admin typed operations

Validate:

- create driver
- approve driver
- top up balance
- change city
- block/unblock

Expected:

- balance top-up changes only balance-related fields
- city update preserves role/mode/status
- block/unblock does not corrupt unrelated fields

### 7. Vehicle photo deletion workflow

Validate:

- driver requests vehicle photo deletion
- admin sees pending request
- admin approves or rejects

Expected:

- no silent direct delete
- deletion happens only after admin approval
- audit trail remains

### 8. Keyboard / order layout

Validate:

- taxi order
- delivery order
- intercity order

Expected:

- CTA stays above keyboard
- suggestion lists remain scrollable
- routes/villages are not hidden by CTA

### 9. iOS marker / map behavior

Validate on iPhone:

- switch selected village A -> B
- open driver map
- open passenger map

Expected:

- selected marker updates correctly
- driver map opens with sane camera/bounds
- no repeated manual zoom requirement

## Rollout verification signals

After the new build is in use, watch for:

- no new reports of passenger-mode redirect after driver push
- no new reports of loser-driver white screen
- no new reports of stale active order after terminal status
- no new reports of failed first login after logout
- no new reports of city/balance admin mutation corrupting role/mode

## Safe post-rollout removal order

Only remove these after manual QA is green and the new build is the dominant
build in production.

### Phase 1

- remove reads of `users.activeMode`
- keep `getUserActiveMode(...)` only if generated/UI code still calls it

### Phase 2

- remove fallback reads from local `FFAppState.idOrder`
- remove fallback reads from local `FFAppState.idOrderDriver`
- remove `lib/backend/order_state_compat.dart`

Prerequisite:

- all supported mobile builds already use backend user-doc order refs reliably

### Phase 3

- remove compatibility-only push metadata handling for:
  - `initialPageName`
  - `parameterData`
  - `parameter_data`
  - `initial_page_name`

Prerequisite:

- push routing is confirmed stable on current production builds

### Phase 4

- remove dormant legacy booleans:
  - `FFAppState.driver`
  - `FFAppState.passenger`

Prerequisite:

- no generated/plugin code still reads them

### Phase 5

- remove backend mirror writes:
  - `users.idOrder`
  - `users.idOrderDriver`

Prerequisite:

- compatibility window for older app builds is closed

## Removal rule

Do not remove a compatibility layer just because the new code exists.
Remove it only when:

1. manual QA is green
2. rollout is stable
3. old builds are no longer materially active
