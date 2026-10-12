# TrialScope

An iOS app for finding clinical studies, saving studies for later, and keeping notes. Built with Swift 6, SwiftUI, and SwiftData.

The current version runs entirely on 18 fictional studies bundled with the app. Backend integration and cloud sync are planned. Search results do not establish medical eligibility.

<img src="docs/screenshots/01-discover.png" width="260" alt="Discover studies"> <img src="docs/screenshots/02-search-results.png" width="260" alt="Search results"> <img src="docs/screenshots/03-study-details.png" width="260" alt="Study details">

[Full screenshot gallery](docs/screenshots/README.md)

## Features

- Search by condition, keyword, or city.
- Filter by recruitment status, study phase, and age.
- Browse paginated results and study criteria.
- Save studies and notes locally for offline access.
- Share study details using the native share sheet.
- Try empty results, delayed responses, and failure recovery with the mock service.

Settings includes switches for simulated failures and slow responses. These reset on launch; saved studies and notes persist.

## Getting started

Requires Xcode 16 or later and an installed iOS simulator runtime. The deployment target is iOS 17. The latest validation used Xcode 27.0 and an iPhone 18 Pro simulator running iOS 27.0.

1. Open `TrialScope.xcodeproj`.
2. Select the **TrialScope** scheme and an iPhone simulator.
3. Run with **⌘R**.

For a physical device, select your signing team in Signing & Capabilities and use a unique bundle identifier.

## Project structure

```text
App/                         App entry point, assets, privacy manifest
Packages/TrialKit/
  Sources/TrialCore/          Models, search service, state, persistence
  Sources/TrialUI/            SwiftUI screens and UIKit sharing
  Tests/TrialCoreTests/       Search, concurrency, and persistence tests
TrialScopeUITests/            XCTest UI flows
scripts/                     Project generation and screenshot export
docs/                        Architecture, validation, and screenshots
```

`TrialService` separates the UI from the data source. The mock implementation supports filtering and pagination; a backend client can implement the same protocol. `SearchModel` cancels superseded requests and rejects stale responses. SwiftData stores complete study snapshots and notes so saved details remain available offline. UIKit provides the share sheet.

See [architecture](docs/Architecture.md) for the state and persistence decisions. The Xcode project can be regenerated with `python3 scripts/generate_project.py`; keep the generator in sync with project-setting changes.

## Tests

Run the package tests with full Xcode selected:

```sh
swift test --package-path Packages/TrialKit
```

Run the UI suite, replacing the simulator name if needed:

```sh
xcodebuild test -project TrialScope.xcodeproj -scheme TrialScope \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

The latest run passed **11 logic and persistence tests** and **4 UI tests**. UI tests use an in-memory store; persistence tests use isolated stores. Test results and remaining manual checks are in [QA](docs/QA.md).

[GitHub Actions](.github/workflows/ios.yml) runs package and simulator tests. UI screenshots can be exported using [these instructions](docs/screenshots/README.md).

## Next steps

- Connect the search service to the Clinical-Trial-SearchEngine backend after validating its API contract.
- Verify physical-device, iPad, VoiceOver, and larger text layouts.
- Implement and test [CloudKit sync](docs/CloudKit.md). The default app uses local storage only.
