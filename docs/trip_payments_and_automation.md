# Fare negotiation, passenger payments and trip automation

Passenger fares are whole tenge, 500–10,000,000 KZT. Drivers can accept the posted fare or propose a different fare. A proposal is valid for two minutes; only the order owner can accept it. Assignment, commission debit and any re-reservation at the agreed fare happen in one store transaction. Losing, expired and declined offers cannot assign the order. Driver ratings come from passengers' completed trips, once per trip; new drivers show no rating. ETA uses a road route and fresh driver location, without traffic, or is explicitly unavailable.

Passenger cash and passenger bonuses are distinct balances. Default cashback is 2%, editable in admin (`passengerBonusPercent`, 0–100). `passengerBonusSpendPercent` defaults to 100, permitting an entirely bonus-funded fare. Cash mode may use bonuses with the remainder paid physically; wallet mode reserves the remainder from the passenger cash account. Insufficient wallet funds change nothing. The server reserves funds on order creation and re-reserves on an accepted counteroffer. Cancellation/expiry releases the reserve once. Completion credits all reserved wallet/bonus value to the driver's cash balance once, then awards passenger cashback. Physical cash is collected directly by the driver. The driver screen explicitly distinguishes cash to collect and account credit. Driver bonuses still only pay commission, cannot be withdrawn and are separate from passenger bonuses.

Passenger top-ups use `createPassengerTopUpPayment` and manual Kaspi invoices. The passenger enters an amount and Kaspi phone. An admin receives the request, issues the invoice externally and confirms only after checking payment. Existing payment IDs/idempotency prevent repeated confirmation from minting money. This is not an automated bank integration.

Trip statuses must progress 2 (assigned) → 3 (arrived) → 4 (started) → 5 (completed). Repeating the current active status is harmless. Skipping statuses is denied. Once started, passenger cancellation and administrative cancellation/reopen/status rollback are denied. A completed trip cannot be reopened to create another payout. Account deletion cannot erase an assigned/started trip. Commission is debited at assignment, refundable once before start and retained after start.

Automatic transitions use server receipt times and GPS samples from the authenticated assigned driver:

- Accuracy must be positive and at most 40 m. Samples with gaps over 20 seconds or implied speed over 55 m/s reset the continuity timer.
- Remaining within 60 m of pickup for 15 seconds automatically marks arrival.
- After verified pickup presence, remaining at least 100 m from pickup for 15 seconds automatically starts the trip.
- Manual arrival also needs a fresh (≤30 seconds), accurate location within 120 m of pickup when pickup coordinates are available.
- The app attempts to publish fresh active-trip GPS positions every three seconds while its active trip screen and location permission are available. GPS acquisition and network latency can delay samples. Changes occur on the first qualifying subsequent sample; without fresh GPS/network data the server does not invent movement or advance a timer.

This resists accidental GPS jumps, duplicate actions and status/refund races. Phone-supplied GPS is not proof against device-level spoofing or collusion. Background/locked-phone delivery and real-road maneuver/voice quality require physical Android/iOS tests before launch.

Both active-trip screens display road routes and fresh driver positions. Driver voice instructions use the device's Russian TTS voice, preferring an available female voice; enable using the speaker button. Availability and voice quality depend on installed device/browser voices. OpenStreetMap tiles and the public OSRM server have no application API fee but no production SLA; a controlled routing/tile service should be considered as traffic grows.

Tests in `server/test/trip_economy.test.js` cover wallet/bonus accounting, replay/refund protection, price negotiation, expired/unauthorized offers, GPS continuity, status skipping, admin restrictions, Kaspi confirmation and ratings. They run against JSON by default and against an explicitly disposable PostgreSQL database when `MTAXI_TEST_POSTGRES_URL` is set. Never point that variable at live data.

The test APK version is 1.2.0 (58). Test signing is now retained privately on the VPS for future upgrades. The previous 1.1.1 APK used an ephemeral test key; uninstall that old test build once before installing 1.2.0. Account data remains on the server. Store distribution still needs a production signing key.
