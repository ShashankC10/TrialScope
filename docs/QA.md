# QA checklist and validation

## Automated coverage

- Fixture decoding and stable unique demo IDs.
- Case/diacritic normalization and all-token search semantics.
- Composed phase/recruitment/age filters, including boundary ages.
- Pagination completeness and no duplicates.
- Invalid pagination and ages rejected explicitly.
- Cancellation and out-of-order response protection.
- Failure/retry and pagination failure preserving current results.
- Idempotent bookmarks, notes, removal, corrupt snapshots.
- Disk persistence across container recreation.
- UI flows: search/save/note/remove, empty/reset, filter validation, failure/retry.

## Manual device checks

- Run on a small iPhone and iPad; rotate both.
- Test light/dark appearance and the largest accessibility text size.
- Navigate using VoiceOver, checking search, filters, cards, and toolbar controls.
- Save and annotate a study, force-quit, relaunch, and verify the snapshot and note.
- Turn on airplane mode; all mock functionality should still work.
- Open the native share sheet on iPhone/iPad; cancel without sending anything.
- Check rapid successive searches under slow response mode.
- Verify a page failure preserves already loaded results.
- Profile search and scrolling on a physical device with Instruments.

## Validation record

Project syntax and privacy manifest passed `plutil -lint`.

### Xcode validation

- Xcode 27.0 (27A266a) installed.
- Full-Xcode `swift test`: **11 tests passed** across mock search, search state, and SwiftData persistence. SwiftUI package compiled on macOS as part of this build.
- `xcodebuild -list`: project, local package, app target, and UI-test target resolved successfully.
- iOS Simulator `build-for-testing`: **passed**, including app and UI-test compilation for arm64 and x86_64.
- iPhone 18 Pro simulator, iOS 27.0: **4 UI tests passed, 0 failures**, on October 11, 2026. Search/save/notes/removal, empty/reset, filter validation, and simulated failure/retry all passed.
- Saved 10 original XCTest screenshots in [the gallery](screenshots/README.md). Discover, filters, and failure screenshots were visually inspected.
- Machine-readable UI results: [ui-summary.json](test-results/ui-summary.json). Package test output: [swift-test.log](test-results/swift-test.log).
- The manual device checklist above remains pending; physical-device, iPad, VoiceOver, and CloudKit verification are not claimed.
