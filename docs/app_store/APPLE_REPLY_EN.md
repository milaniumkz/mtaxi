# Complete working response — MTaxi.kz 1.3.1 (66)

Local preparation note: verify the installed build, beta history and source provenance before sending. Remove this note and any CHECK_ON_MAC paragraph from the final message. Ownership below was explicitly confirmed by the owner on 2 November 2026. Do not invent missing beta or market evidence.

Hello App Review team,

Thank you for the detailed questions concerning Guidelines 4.3(a), 4.3(b), and 4.2.6 for MTaxi.kz (Apple ID 6826563434), version 1.3.1, build 66. We acknowledge that MTaxi originated from our Taxi 24 codebase (Apple ID 6761094545). We are not claiming that the application is unrelated to that codebase or that a change of branding or geography alone establishes compliance.

1. What the app does and the primary problem it solves

MTaxi coordinates local rides and deliveries between passengers and drivers approved by the service operator. The passenger enters pickup and destination addresses and proposes a fare. A driver can accept that amount directly or make a counteroffer. Before agreeing, the passenger reviews the driver's information, price and estimated pickup time. A pending counteroffer expires after 30 seconds and does not automatically assign a driver.

After assignment, the app records trip progress and settlement. It distinguishes passenger monetary funds from promotional bonuses, and distinguishes driver monetary earnings from driver commission bonuses. Passenger bonuses can cover part or all of an eligible trip; driver bonuses cannot be withdrawn and are used for service commission. Kaspi top-ups follow an invoice-and-manual-verification workflow, rather than crediting money merely when a request is created. The problem we address is coordinating a local trip and agreeing its price while keeping the trip state and monetary obligations consistent for both participants.

CHECK_ON_MAC: Confirm which workflows actually exist in build 66, and describe subsequent changes as subsequent changes, not features already reviewed in 66.

2. Intended users

The intended users are passengers requesting local rides or deliveries and drivers approved by MTaxi. The configured launch area includes Zhetekshi, Zhelezinka, Terenkol and Irtyshsk in the Pavlodar region of Kazakhstan. Passengers enter their route and agree a fare; drivers view requests and accept or counteroffer. The interface supports Russian and Kazakh. Registration uses a phone number and password and does not require a Telegram account.

CHECK_ON_MAC: Confirm the locations actually served versus intended launch locations and the actual driver/fleet arrangement. Add user numbers only if documented; do not turn an intended service area into an unsupported claim of operating coverage.

3. Need or market gap addressed

The service is being developed for local fare agreement and operator-managed rides with payment options usable by its intended audience: cash, an application monetary balance, promotional bonuses and locally verified Kaspi invoices. Development requirements included making both route endpoints immediately visible, making counteroffers explicit, and explaining the different uses of monetary and promotional balances. The owner also identified that requiring a separate messenger account or costly SMS authentication would be inappropriate for the intended audience.

We do not claim that negotiated prices, maps or bonuses are globally unique; other apps offer individual elements of this workflow. Our case concerns the complete service and how these operational requirements are handled together, rather than an assertion that other ride apps do not exist.

CHECK_ON_MAC: Add the owner's concrete evidence of an unmet local user need or an existing service limitation, if available. Do not claim that competitors are absent or that this app is uniquely capable without evidence. If no substantive gap can be supported, acknowledge that issue rather than inventing one.

4. Beta testing and feedback applied to the build

The documented development process includes owner-led manual functional feedback and automated regression tests. Owner feedback included: showing pickup and destination together on the order form; making taxi/delivery icons visible; replacing manual driver counteroffer input with proportional buttons; correcting unreadable in-app notifications; and correcting a slow or premature arrival announcement. Changes addressing these issues are present in the source history.

We distinguish those checks from external iOS/TestFlight beta testing. We do not treat automated tests or web/Android checks as evidence of an iOS beta, and do not describe tests performed after submission as pre-submission testing.

CHECK_ON_MAC: Complete this answer with the actual pre-submission iOS test dates, devices, participants, distribution method and feedback incorporated into build 66. If there was no external iOS beta, state that explicitly. Identify which listed fixes shipped in 66. Include a genuine new TestFlight report separately if testing is conducted now. Do not fabricate testers, dates or feedback.

5. Standalone product or suite

MTaxi is intended as a standalone service. We also publish Taxi 24 and acknowledge the relationship. Taxi 24's public listing describes taxi, delivery and intercity trips in the Glubokoye district. MTaxi's present configuration disables intercity and uses the fare-agreement and settlement workflows described above. We recognize that disabling one feature or using another service area alone would not establish a distinct product.

The MTaxi interface has been reworked around separate trip, wallet, history and profile sections; a compact order composer with the map above the route fields; and explicit driver counteroffer and waiting/expiry interactions. The attached evidence should show actual user journeys, including areas of overlap, rather than claiming there are no common functions.

CHECK_ON_MAC: Verify other related apps under this account and compare the actual Taxi 24 functionality/source if available. Do not infer that a feature is absent from Taxi 24 simply because it is not shown in public screenshots. Confirm actual separation of service operations/infrastructure before asserting it.

6. Could the functionality be delivered within another app on the account?

Technically, one application could support multiple service areas or operators and these workflows. We do not claim that separate databases or a different brand make consolidation impossible. The intention is to operate MTaxi as an independently presented service with its own operational workflow, not simply another city entry with a different icon. We understand that business preference or geography alone may not satisfy Guideline 4.3(a).

CHECK_ON_MAC: Include the owner's actual substantive operational, contractual or product reason for separate distribution and its effect on users. Do not invent a legal requirement or technical barrier. If no such reason exists beyond city/brand, resolve the consolidation concern before asserting that the separate app meets this guideline. Renaming a bundle or removing Taxi 24 from sale is not an explanation of that distinction.

7. Significant shared code, frameworks or assets with our other apps

Yes. MTaxi began with the Taxi 24 application foundation. We disclose this directly rather than saying it was written entirely from scratch. The inherited areas requiring a verified comparison include the Flutter project structure, FlutterFlow-generated helpers, navigation/app state, account/profile interfaces, map/address input, order presentation and balance/history components. These provide the underlying application navigation, user identity, trip entry and presentation functions.

The current MTaxi source reworks order composition, role-specific navigation, driver counteroffers, response deadlines and monetary/promotional balance presentation. Server-side offer expiry, settlement and bonus calculations support those experiences, but we recognize that server code is not part of the iOS binary. Standard dependencies include Flutter, Firebase Core/Messaging, flutter_map, geolocator, http, go_router and shared_preferences.

CHECK_ON_MAC: Supply a factual common-component/asset inventory against the available Taxi 24 revision. The MTaxi import commit is not independently established as the shipped Taxi 24 source. Do not invent a shared-code percentage or claim that all common custom assets have been removed.

8. Shared components with third-party apps beyond standard frameworks

The project includes FlutterFlow-generated helpers and subsequent application-specific modifications. Development tools, including AI-assisted coding, have been used. The client/server code audit did not identify an application-specific external LLM integration; development tooling should not be confused with an in-app AI feature. We do not claim that using such tools establishes originality or exempts the application from Guideline 4.3.

CHECK_ON_MAC: Confirm whether the original Taxi 24 foundation was built by the owner, commissioned, purchased or licensed from a template vendor. If there is a commercial template or nonstandard third-party application library, identify the vendor/component and its role, its license and the original functionality added. If there is none, state that only after verifying provenance. We cannot identify every unrelated app that might use a vendor's foundation merely from this repository.

9. Client/partner/content provider and developer account

The Apple Developer account and the MTaxi service are owned by the same individual. The owner also owns IP Milanium, the operator named in MTaxi's service documents. MTaxi is the owner's own application and service, not an application being submitted on behalf of a separate client or content provider. The concept, branding and service operations are provided by the owner. We can supply appropriate evidence of the relationship between the individual account holder and the individual entrepreneurship through the channel you request.

We are not asserting that an individual developer account is an organization account. The service contact is milaniumkz@yandex.kz. We understand the requirement for direct submission by the actual content provider under Guideline 4.2.6 and the separate requirement for substantive product differentiation under Guideline 4.3.

We understand your instruction not to resubmit the same product without substantial improvements. Any build comparison, screenshots, demonstration video or beta report supplied with this response will relate to the actual iOS version and will be labeled accurately. We respectfully request your assessment of the verified service workflows, substantive differences and direct content-provider relationship described above.

Thank you.
