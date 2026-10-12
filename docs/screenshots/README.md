# Simulator screenshots

Original, unmodified PNG attachments captured by the XCTest UI suite on an iPhone 18 Pro simulator running iOS 27.0. All studies and notes shown are fictional demo data.

`manifest.json` records each image's originating test, device, and timestamp. These are screenshots of exercised app states, not a substitute for the test results in `../test-results/` and the validation record in `../QA.md`.

## Main experience

| Discover | Results | Details |
| --- | --- | --- |
| <img src="01-discover.png" width="240" alt="TrialScope Discover screen"> | <img src="02-search-results.png" width="240" alt="Search results for breast cancer"> | <img src="03-study-details.png" width="240" alt="Fictional study details"> |

| Saved studies | Notes | Recruiting filter |
| --- | --- | --- |
| <img src="04-saved-studies.png" width="240" alt="Offline saved study"> | <img src="05-saved-notes.png" width="240" alt="Saved study with a private note"> | <img src="07-recruiting-filter.png" width="240" alt="Recruiting filter switched on"> |

## Tested edge cases

| Invalid age | Empty results | Service failure |
| --- | --- | --- |
| <img src="06-filter-validation.png" width="240" alt="Invalid age prevents applying filters"> | <img src="08-empty-results.png" width="240" alt="Empty search with reset action"> | <img src="09-service-error.png" width="240" alt="Simulated service failure with retry action"> |

After disabling the simulated failure and retrying: [recovered results](10-recovered-results.png).

## Recreate

Run the UI suite with `-resultBundlePath /tmp/TrialScope-new.xcresult`, then:

```sh
xcrun xcresulttool export attachments \
  --path /tmp/TrialScope-new.xcresult --output-path /tmp/trialscope-attachments
python3 scripts/export_screenshots.py /tmp/trialscope-attachments
```

Run commands from the project root. The exporter only copies explicitly named PNG attachments; recordings, failure hierarchies, and host paths are not copied into this gallery.

For a GitHub README at the repository root:

```html
<img src="docs/screenshots/01-discover.png" width="260" alt="TrialScope Discover">
<img src="docs/screenshots/02-search-results.png" width="260" alt="Trial search results">
<img src="docs/screenshots/03-study-details.png" width="260" alt="Study details">
```
