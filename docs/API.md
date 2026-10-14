# Backend connection

The client targets [Clinical-Trial-SearchEngine](https://github.com/ShashankC10/Clinical-Trial-SearchEngine), inspected at commit `260552853aaa9a4ac16015999e5fc502d5ac9041`.

Contract sources: [API models and routes](https://github.com/ShashankC10/Clinical-Trial-SearchEngine/blob/260552853aaa9a4ac16015999e5fc502d5ac9041/backend/api/main.py), [ingestion field values](https://github.com/ShashankC10/Clinical-Trial-SearchEngine/blob/260552853aaa9a4ac16015999e5fc502d5ac9041/backend/db/scrape_clinical_trials.py), and [index mapping](https://github.com/ShashankC10/Clinical-Trial-SearchEngine/blob/260552853aaa9a4ac16015999e5fc502d5ac9041/backend/search/reindex_from_postgres.py).

## Configuration

Normal launches use `API_BASE_URL` from the app process environment. There is no URL hardcoded in Swift and no automatic fallback to demo data. Missing or invalid configuration produces a startup error.

For Xcode: **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**. Add `API_BASE_URL` with your server base URL, for example `http://localhost:8000`. Leave `TRIALSCOPE_USE_MOCKS` unset or set it to `0`.

For command-line simulator launches:

```sh
cp .env.example .env   # first setup only; preserve any existing local settings
# Edit .env as needed, then:
./scripts/run-simulator.sh
```

The launcher reads the ignored `.env`, builds and installs the app, and passes the variables to the simulator process. Xcode does not automatically read `.env`. An optional first script argument selects a simulator UUID. Launch the app through Xcode or this script when you need environment variables; an ordinary tap on the installed app does not retain a previous debugger launch environment.

`localhost` reaches the Mac's server from the simulator. On a physical iPhone, use the Mac's reachable `.local` hostname, run the backend on a reachable interface, and allow local network access. The plist permits local networking without globally disabling App Transport Security; use HTTPS for hosted servers. See [Apple's local-network ATS setting](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking).

## Requests and response mapping

| App action | Request | Behavior |
| --- | --- | --- |
| Search / refresh | `POST /rank` | Sends `query`, `profile.age` when supplied, and optional `phase` and `overall_status` filters. |
| Load more | No new request | Displays the next slice of the already returned top-20 window. |
| Open search result | `GET /trials/{nct_id}` | Loads full criteria and structured locations before allowing a save. |
| Open saved study | No request | Reads the saved full-detail snapshot and notes. |

The rank payload uses `PHASE1`, `PHASE2`, `PHASE3`, and `RECRUITING`, matching the ingestion/index code. The endpoint descriptions contain title-case examples, but the indexed values come directly from ClinicalTrials.gov enums.

The backend fixes `/rank` to page 1, size 20. `total` and `candidate_total` may describe hundreds of candidates; the app counts only returned hits and labels the top-20 limit. Observational is a `study_type`, not a supported server phase filter, so it narrows the returned window locally. This can miss observational studies outside that window. A future backend change is needed for unrestricted ranked pagination and a server-side study-type filter.

The app does not invent gender, biomarkers, medical history, or laboratory values. Search terms and age are sent to the configured server. Server logging and retention apply; notes remain local and are not sent. Ranking/filter behavior is owned by the backend and does not establish eligibility.

Search DTOs decode `hits`, `nct_id`, `brief_summary`, string locations, and nullable ages. Detail DTOs decode structured locations and `criteria_inclusion` / `criteria_exclusion`. Unknown status and phase strings remain visible. Missing metadata displays “Not provided”; missing ages display “Unknown”. Sponsor is not returned by these endpoints. Full raw eligibility text is retained separately rather than guessed into inclusion/exclusion groups.

Non-success HTTP status, malformed responses, transport failures, and cancellation propagate to the UI. Server error bodies are not displayed or logged. The request timeout is 300 seconds, matching the existing backend frontend client.

## Mock data and tests

Set `TRIALSCOPE_USE_MOCKS=1` for an offline demo. XCTest launches with `--uitesting`, which always selects mocks and an in-memory store even if `API_BASE_URL` is present.

The original `trials.json` used app-domain keys and did **not** match the API. It now contains an array of 18 fictional `TrialDetail` response objects using the API's field names and types. Each object passes through the same decoder and mapping as a live detail response. The enclosing array is a catalog container, not an endpoint response. DEMO IDs intentionally identify fictional studies and must not be sent to the real detail endpoint.

`APIContractTests` injects a URLSession with URLProtocol responses shaped as `SearchResponse` and `TrialDetail`. Tests cover request method/path/body, filters, nullable and unknown fields, cached pagination, refresh, empty results, invalid responses, HTTP errors, timeout, and cancellation. Mock keyword ranking remains deterministic; it does not reproduce the server's retrieval and feasibility models.

These are contract tests against the inspected source, not a live backend integration test. On October 14, 2026 the local health probe at port 8000 found no running server.
