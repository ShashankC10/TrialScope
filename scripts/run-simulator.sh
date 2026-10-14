#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi
if [[ "${TRIALSCOPE_USE_MOCKS:-0}" != "1" ]]; then
  : "${API_BASE_URL:?Set API_BASE_URL in .env or export it before running this script}"
fi
DEVICE_ID="${1:-$(xcrun simctl list devices available -j | python3 -c 'import json,sys; devices=[d for runtime,ds in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in ds if d["name"].startswith("iPhone")]; print(next((d["udid"] for d in devices if d["state"] == "Booted"), devices[0]["udid"]))')}"
BUILD_DIR="${TRIALSCOPE_BUILD_DIR:-$ROOT/DerivedData}"
xcrun simctl bootstatus "$DEVICE_ID" -b
xcodebuild build -project TrialScope.xcodeproj -scheme TrialScope \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$BUILD_DIR" CODE_SIGNING_ALLOWED=NO
xcrun simctl install "$DEVICE_ID" "$BUILD_DIR/Build/Products/Debug-iphonesimulator/TrialScope.app"
SIMCTL_CHILD_API_BASE_URL="${API_BASE_URL:-}" \
SIMCTL_CHILD_TRIALSCOPE_USE_MOCKS="${TRIALSCOPE_USE_MOCKS:-0}" \
  xcrun simctl launch --terminate-running-process "$DEVICE_ID" com.shashank.TrialScope
