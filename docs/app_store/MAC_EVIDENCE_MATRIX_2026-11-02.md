# Mac evidence matrix — 2 November 2026

## Source and ownership

- Working branch fetched from origin: `codex/full-audit-20261023`, starting revision `aabfc55`. The checkout was clean before switching from the preserved release branch. No reset/stash or user-file replacement was performed.
- Owner's latest clarification: the original Taxi 24 foundation was created by him; a prospective client did not purchase it. Taxi 24, MTaxi, the Apple individual account and IP Milanium belong to the owner. Taxi 24 is reportedly not used operationally. It has not been removed, modified or treated as a compliance workaround.
- Earlier statement of no common code was incorrect and is expressly corrected in the final Apple response. No commercial template vendor was identified by the owner. Ownership is owner-confirmed, not an assertion that a contract has been independently examined.
- The local `taxi 24` directory is empty. Exact shipped Taxi 24 source/binary comparison remains unavailable. MTaxi import statistics must not be presented as such a comparison.

## What can be demonstrated

| Area | Evidence | Limit |
| --- | --- | --- |
| Fare negotiation | Source, server tests, Flutter UI tests: original amount, counteroffer, actual surcharge/reduction, 30-second deadline and expired acceptance handling | Does not prove Taxi 24 lacks the same feature or global uniqueness |
| App composition | Source and visual fixtures: trip, wallet, history and profile sections; compact order composer | Visual fixtures are not native iOS screenshots; branding/layout alone do not resolve 4.3 |
| Settlement and bonuses | Source/server tests: explicit repricing, money versus promotional funds, idempotent ledger and verification before top-up credit | Not proof of real banking operations or a completed physical iPhone trip |
| Local need | Owner reports telephone dispatch and manually remembered route details in intended Pavlodar settlements | No claim that competitors are absent; intended coverage is not confirmed operating coverage |
| Beta | Owner reports 60 days with five people, web and Android | No external iOS/TestFlight beta established |
| Build 66 | Preserved signed `.xcarchive` and `.ipa`; main 1.3.1/66, extension 1.1.1/57 | Exact source commit is not embedded in the archive; do not equate every current feature with 66 |
| New native version configuration | Shared Flutter-generated version settings replace fixed extension metadata | Must also pass actual archive verification, not just source inspection |
| Denied GPS | Native simulator 67 reproduced a fallback/cached centre wrongly selected as pickup. Regression fails on old source; source fix and 104 functional tests pass. Native simulator 68 confirms blank unselected pickup with location denied | Quality/safety correction, not a claim of unique taxi functionality or physical-device testing |

Signed archives 67 and 68 passed actual metadata/Firebase/signature checks and were uploaded through Xcode. Both finished processing and became Ready to Submit; the current build 68 contains the native-test-discovered GPS correction, confirmed on the actual native simulator. Production URLs and both protected reviewer logins were verified. The exact status and remaining native walkthrough gaps are recorded in `MAC_EXECUTION_RESULT.md`; an upload does not constitute App Review submission. The full nine answers and a technical addendum with the actual native screenshot were sent in the original App Review thread.

## New changes relative to the prior submitted work

The branch's post-66 audit corrects counteroffer deadline display/expiry, provides original fare and surcharge/reduction before consent, replaces unreadable offer glyphs, removes unused iOS calendar permission, preserves font notices, explains the service offline and aligns Runner/ImageNotification versions. Web Firebase startup timeout is a web fix, not an iOS binary feature. The Mac work restores the driver online profile mapping from the previous release branch; that mapping is preservation of build-66 behavior, not a new differentiation claim. Normal `pod install` reconciles installed Flutter plugins without a mass dependency upgrade.

## Current submission decision

Apple's message of 2 November reiterates a need for distinct content/functionality and refers back to its initial nine questions. The verified changes are quality/consent/metadata corrections. They have not established a materially separate product from the same owner's unused Taxi 24. No contractual or technical requirement for separate distribution has been established; the owner describes a local telephone-dispatch problem. The full corrected response must be sent. A new signed build may be uploaded for testing, but App Review resubmission remains conditional on resolving this substantive concern or further instructions from Apple. A new build number is not evidence of compliance.
