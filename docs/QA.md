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

### API client update — October 14, 2026

- Local Swift suite: **18 tests passed** (11 existing logic/persistence tests and 7 API contract tests).
- HTTP tests use injected URLProtocol responses; no live backend is required.
- iOS app and UI-test targets compiled successfully. The broader UI run was stopped at the user's request; the earlier four passing UI tests above describe the previous mock-only build.
- Full simulator, physical-device, and running-backend validation of this update is deferred.
- The port 8000 health probe found no running backend. See [API setup](API.md).

### UI overhaul — October 14, 2026

- Redesigned Discover (compact header, inline search, filter chips, skeleton loading with cancel), cards, study details (toolbar save, readable eligibility, collapsible site list and original criteria), and saved cards with note previews. Age, site, and condition formatting for live registry data was fixed.
- Local Swift suite: **19 tests passed**, including a new presentation-formatting test.
- iPhone 18 Pro simulator, iOS 27.0 (mock mode): **4 UI tests passed, 0 failures**. `ui-summary.json` is from this run.
- Gallery now has 12 original screenshots, including eligibility criteria and applied filter chips. Discover, results, details, saved, and filter states were visually inspected.
- Still pending: physical device, iPad, VoiceOver, largest text size, dark mode review, and a live-backend run. Note: `swift test` failed codesigning inside `Documents` because of extended attributes; use `--scratch-path` outside the repo.

### Response-mapping review — October 14, 2026

Fixed blank title/description fallback handling and guarded age formatting against out-of-range numeric values. Added regression tests for both. All **21 local tests passed**. No simulator or live-backend tests were run for this review.
