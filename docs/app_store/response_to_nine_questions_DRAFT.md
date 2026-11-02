# MTaxi.kz 1.3.1 (66): draft response to Apple’s nine questions

**NOT READY TO SEND.** Owner confirmations are marked below. Do not replace missing facts with guesses. Do not resubmit a binary while the review team is requesting these answers. The existing short clarification letter does not answer this questionnaire and should not be sent instead.

Hello App Review team,

Thank you for identifying the concerns under Guidelines 4.3(a), 4.3(b), and 4.2.6 for MTaxi.kz, Apple ID 6826563434, version 1.3.1, build 66. We acknowledge that the project originated from the codebase used for Taxi 24 (Apple ID 6761094545). We understand that a different brand, service area or backend alone does not establish a sufficiently distinct product. Our responses are below.

## 1. What the app does and the primary problem it solves

MTaxi connects a passenger requesting a local ride or delivery with an approved driver. The passenger enters pickup and destination addresses and proposes a fare. The driver either accepts that fare or submits a counteroffer. The passenger reviews the offered fare, driver details and estimated pickup time and accepts or declines; a pending counteroffer expires after 30 seconds. After assignment, the app displays trip progress and records completion and the resulting settlement.

The implementation includes a passenger cash balance and promotional bonus balance. Available passenger bonuses can cover part or all of a trip. A driver's promotional bonus balance is separate from the cash balance and is used for platform commission, not withdrawals. A Kaspi top-up is a manually verified invoice workflow: requesting a top-up does not credit money until the operator verifies payment. These are operational workflows, not claims that the features are unique across the App Store.

The primary intended problem is coordinating an actual local ride and agreeing its fare with an available driver while recording status and payment obligations. **Before sending:** verify this complete description against installed build 66. Current repository code alone does not establish what that binary contains.

## 2. Intended users

The intended users are passengers requesting local rides/deliveries and drivers approved by the service operator, including users in the configured settlements around Pavlodar: Zhetekshi, Zhelezinka, Terenkol and Irtyshsk. Passengers use the app to request and agree a ride; drivers use it to view requests, accept a fare or counteroffer, and manage their service balance. The application provides Russian and Kazakh interface localization.

**OWNER CONFIRMATION REQUIRED:** specify the settlements actually served, whether drivers are independent or part of a contracted fleet, the real operating service, existing passenger/driver numbers if documented, and which user needs have been observed. Do not claim rural coverage, low-connectivity operation, driver availability or adoption that has not been measured.

## 3. Need or market gap not adequately addressed by existing apps

**OWNER CONFIRMATION REQUIRED — cannot be established from the repository.** Describe an observed problem in the actual service area, how existing services perform there, and what this app demonstrably improves. Supply concrete examples from users/operations, with permission and without unnecessary personal data.

We must not claim that passenger-set fares, counteroffers, bonus wallets or ordinary ride tracking are new to the App Store. For example, the public inDrive description already includes passenger-set prices, driver counteroffers and selecting a driver by price, rating and arrival time. A local city name alone is not an answer to the differentiation concern.

## 4. Beta testing and feedback incorporated into the submitted production build

**OWNER CONFIRMATION REQUIRED:** who tested the iOS app, dates, number of passengers/drivers, TestFlight use, devices/iOS versions, scenarios, original feedback, and which exact changes are in build 66. If no external iOS beta occurred, say so; do not call automated tests or owner web testing a TestFlight beta.

Documented development feedback from the owner includes: pickup and destination should be immediately visible, taxi/delivery icons were missing, driver counteroffers should be proportional buttons rather than a manual amount, an in-app notification was unreadable, and an arrival voice prompt sounded slow/incorrect. Changes addressing these reports are present in the repository history. They are **not independently verified as incorporated into the submitted iOS build**.

Repository checks include automated Flutter/backend tests and owner-led web feedback. Some checks were performed after submission; their counts must not be represented as pre-submission beta evidence. Provide the real iOS beta results before completing this answer. No tester identities, comments or usage metrics have been fabricated.

## 5. Standalone product or part of a suite

The owner intends MTaxi to operate as a standalone service. The developer account also publishes Taxi 24, and MTaxi's initial codebase came from that project. Taxi 24's public listing advertises local taxi, delivery and intercity rides in the Glubokoye district; MTaxi's configuration currently disables intercity. The submitted comparison must also describe overlapping functions, not only differences.

**OWNER CONFIRMATION REQUIRED:** identify all related apps, their operators, audiences, shared infrastructure and practical scope. Explain what is actually independent. Do not assert that the apps have no relationship or that disabling intercity establishes a new product. The complete Taxi 24 source/binary is not available for verification here.

## 6. Could the functionality be consolidated into another app on this account?

From a technical perspective, selecting a service area/operator and providing ride, delivery, negotiation and wallet functionality within one application is possible. Separate databases or a different visual identity do not by themselves make consolidation impossible.

**OWNER CONFIRMATION REQUIRED:** explain any substantive operational, legal or product reason why consolidation is unsuitable, with evidence. If the only differences are branding, location or ownership preference, do not invent a technical barrier. In that situation consolidation is the stronger compliance route under 4.3(a). A separate service does not automatically require a separate installed app.

## 7. Significant shared code, frameworks or assets with our other apps

Yes: the owner confirms that MTaxi was derived from Taxi 24's source code. The initial application foundation should be disclosed rather than described as entirely written from scratch.

The inherited areas to verify against the actual Taxi 24 revision include the Flutter application structure, FlutterFlow-generated UI/helpers, app state/navigation, account/profile screens, map/address input, order lifecycle UI, balance/history screens and related assets. These support routing, user identity, ordering, map interaction and presentation. This is a **provisional inventory**, not a verified file-by-file comparison. Provide the actual common modules/assets and subsequent modifications when the original source/revision is available. Do not give an invented shared-code percentage.

The current MTaxi source adds/reworks negotiated-price handling, offer expiry/waiting, financial settlement and bonus behavior, role-specific navigation and UI. Some of this is backend logic, which is not part of the iOS binary. Standard dependencies include Flutter, Firebase Core/Messaging for notifications, flutter_map, geolocator, http, go_router and shared_preferences; their presence does not establish that all custom code is independent.

## 8. Shared components with third-party apps beyond standard frameworks

**OWNER CONFIRMATION REQUIRED:** confirm the original source/vendor/license and whether Taxi 24's foundation was itself purchased/licensed from a commercial taxi template or supplied by another developer. If yes, name it and describe the inherited nonstandard components and the original functionality added. Do not state “none” without confirming provenance.

The current repository includes FlutterFlow-generated code/helpers. Using a generation tool is not evidence that no original functionality exists, but we should disclose the actual origin accurately. We cannot determine from this repository which unrelated third-party apps use the same generated/custom codebase.

## 9. Client, partner or third-party content provider and submission account

The service documents identify the operator as IP Milanium, Kazakhstan, IIN 970905350621, with support contact milaniumkz@yandex.kz. Taxi 24's public App Store seller is Dmitriy Shtrakhov.

**OWNER CONFIRMATION REQUIRED:** is the Apple Developer account holder the same person who owns/operates IP Milanium and provides MTaxi's actual service, concept and content? If yes, state that relationship accurately and offer appropriate business documentation through Apple's requested secure channel. Do not claim a company/organization enrollment if this is an individual account.

If MTaxi belongs to a different client/provider, identify the provider and the actual account relationship. For a commercial-template/generated app, Apple specifically requires direct submission by the content provider; a commissioned project or separate app branding alone does not answer this. An ownership/account change should reflect the true provider and Apple's transfer/enrollment requirements, not an attempt to avoid review history.

Thank you. We will address the requested factual clarifications before resubmitting.
