Hello App Review team,

Please treat this as a corrected, complete response concerning MTaxi.kz, Apple ID 6826563434, version 1.3.1 (66). Our reply of 31 October incorrectly said that there was no shared application foundation. The owner has since clarified the history: MTaxi originated from the owner's Taxi 24 codebase. We correct that statement expressly. We acknowledge your additional message of 2 November concerning binary similarities, functionality and overall experience.

1. Function and primary problem

MTaxi coordinates local taxi and delivery requests between passengers and operator-approved drivers. A passenger specifies pickup, destination and a proposed fare. A driver can accept or counteroffer; the passenger must agree before assignment and repricing. The pending counteroffer expires after 30 seconds without automatically assigning a driver. Trip progress, completion, history, ratings and support follow in the same service. Monetary balances and promotional bonuses are accounted for separately. Driver bonuses cover commission and are not withdrawable earnings. Kaspi top-up requests require operator verification; creating a request alone does not credit money.

2. Intended users

Passengers and local drivers in settlements of Kazakhstan's Pavlodar region are the intended launch audience. Configuration includes Zhetekshi, Zhelezinka, Terenkol and Irtyshsk; configuration is not evidence that drivers are already operating in each settlement. The interface supports Russian and Kazakh, with fares in tenge. Drivers require operator approval. Registration uses a phone number and password, without requiring a messenger account.

3. Operational need and market gap

The owner reports that the intended local users currently arrange taxis by telephone: drivers manually remember pickup and destination details and passengers make calls to find transport. MTaxi is intended to replace that process with recorded route requests, a driver request feed and explicit agreement on the fare. This is the concrete local operational problem, not a claim that competing taxi applications do not exist. Negotiated prices, maps and bonuses are not globally unique inventions. We ask you to assess the complete workflow and its implementation, rather than relying on a different name or territory as proof of differentiation.

4. Testing and feedback

The owner reports personally conducting testing with five people over 60 days, on the web version and Android. This was not an iOS/TestFlight beta. No pre-submission external iOS beta dates, devices, TestFlight sessions or attributed iOS beta feedback have been established, and we do not claim such a program occurred. Owner-led development feedback documented in source history concerned displaying both route endpoints, visible taxi/delivery controls, proportional driver counteroffer buttons, readable notifications and arrival announcements. Internal QA separately recorded fixes for stale driver cards after counteroffer acceptance, trip-completion/rating navigation and server-confirmed role switching. Those fixes preceded build 66. Automated regression tests and any new native checks are separate engineering evidence, not retrospective beta-user reports.

5. Standalone product and related apps

MTaxi is intended as the owner's standalone service, but it has a common origin with TAXI 24 APP, Apple ID 6761094545, bundle com.milanium.taxi24. Taxi 24 was developed by the same owner for a prospective client; the owner now confirms that the client did not purchase it, the application remains his, and it is not currently used operationally. Taxi 24's public listing describes taxi, delivery and intercity functions in the Glubokoye district. MTaxi currently disables intercity. We do not infer that Taxi 24 lacks a feature simply because its public screenshots omit it. Its exact shipped source/binary has not been available for a verified comparison. Other transport apps visible in the account have not been established as MTaxi companion applications; we do not assert a verified absence of shared components with every account app.

6. Consolidation into an existing application

Technically, these functions could be consolidated into one application, including through support for additional service areas. The owner's reason for MTaxi is to operate his own local service for the telephone-based workflow described above. We have not established a contractual, legal or technical barrier requiring separate distribution from Taxi 24, and we recognize that brand, geography or business preference alone may be insufficient under 4.3(a). Taxi 24 has not been removed or changed as a purported compliance fix. Please clarify whether consolidation is required in this case or which substantive difference remains insufficient; we will not represent a new build number as resolving this concern.

7. Shared components within the account

Yes: the common Taxi 24 foundation includes Flutter/FlutterFlow application scaffolding, generated helpers, app state/navigation and account, map/address, order and balance presentation structures. These support navigation, identity, route entry and trip presentation. A precise shared-code percentage or inventory against Taxi 24's shipped revision is not established. MTaxi source history reworks the trip/wallet/history/profile composition, compact map-and-route order composer, driver counteroffer/waiting interactions and monetary/bonus presentation. Standard packages include Flutter, Firebase Core/Messaging, flutter_map, geolocator, http, go_router and shared_preferences. Server-side settlement/expiry logic supports the service but is not itself part of the iOS binary. We are not claiming removal of all inherited code or assets.

8. Third-party foundation and rights

The owner confirms that he created the original Taxi 24 foundation himself and retains ownership; the prospective client did not buy it. It was not identified by the owner as a purchased commercial taxi template. FlutterFlow-generated helpers and standard third-party dependencies remain, with applicable notices preserved. Development tools, including AI-assisted coding, have been used; that is not an in-app AI feature or proof of originality. We cannot identify every unrelated application that might use similar standard/generated components from this repository, and make no claim of a complete third-party binary comparison.

9. Content provider and account

Dmitriy Shtrakhov owns this Apple Developer account, MTaxi and its service operator IP Milanium. This is direct submission by the owner/content provider, not submission of MTaxi for a separate client. The individual account is not being represented as an organization account. Service contact: milaniumkz@yandex.kz. Appropriate ownership evidence can be provided through the secure channel you specify; personal documents are not published in the source repository.

Subsequent work corrects the displayed counteroffer deadline and expiration handling, shows the original fare and actual surcharge/reduction before consent, fixes unreadable offer symbols, removes an unused calendar permission and aligns the app/notification extension versions. We distinguish these changes from build 66 and do not claim that quality fixes or a new number alone resolve 4.3. We will provide accurately labeled iOS evidence and follow your required order before any new App Review submission. Please identify any specific comparison or remaining substantive requirement so that it can be addressed without unsupported claims.

Thank you.
