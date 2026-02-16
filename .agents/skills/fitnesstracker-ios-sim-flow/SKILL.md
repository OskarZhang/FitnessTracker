---
name: fitnesstracker-ios-sim-flow
description: Build/test the active FitnessTracker iOS app in Simulator with UI tests as the default verification path, and optionally run deeplink + screenshot capture for visual validation.
---

# FitnessTracker iOS Sim Flow

## Overview
Use this skill to verify UI correctness in this repo. The default path is:
1. Run `FitnessTrackerUITests` on Simulator.
2. If visual evidence is needed, run deeplink + screenshot capture.

Prefer UI tests over deeplink-only checks whenever validating behavior.

## Default Workflow (UI correctness)
1. Confirm you are in the `FitnessTracker` repo root.
2. Build + run targeted UI tests first.
3. Only then run screenshot/deeplink flow for manual visual confirmation if needed.
4. Report:
   - test command used
   - pass/fail and failing step
   - screenshot path (if captured)

## Preferred UI Test Command
```bash
xcodebuild -project FitnessTracker.xcodeproj \
  -scheme FitnessTracker \
  -destination 'id=<SIMULATOR_UDID>' \
  -parallel-testing-enabled NO \
  test
```

For focused validation of add-workout and restoration flows:
```bash
xcodebuild -project FitnessTracker.xcodeproj \
  -scheme FitnessTracker \
  -destination 'id=<SIMULATOR_UDID>' \
  -parallel-testing-enabled NO \
  -only-testing:FitnessTrackerUITests/FitnessTrackerUITests/testAddWorkoutFlow \
  -only-testing:FitnessTrackerUITests/FitnessTrackerUITests/testRestoresPendingSessionAfterBackgroundKill \
  test
```

## Visual Validation (Optional)
If `scripts/run_sim_flow.sh` exists, run:
```bash
scripts/run_sim_flow.sh --deeplink 'fitnesstracker://add'
```

Optional flags:
- `--project` (default `FitnessTracker.xcodeproj`)
- `--scheme` (default `FitnessTracker`)
- `--device` (device name, only if available in current runtime set)
- `--configuration` (default `Debug`)
- `--bundle-id` (default `com.oz.fitness.FitnessTracker`)
- `--output-dir` (default `artifacts/simulator-screenshots`)
- `--screenshot-name` (default `<timestamp>_deeplink.png`)
- `--derived-data-path` (default `.build/ios-simulator-derived-data`)
- `--post-launch-wait` (default `2` seconds)

## Manual Fallback (when script is missing)
Use this exact sequence:

```bash
set -euo pipefail
DEEPLINK='fitnesstracker://add'
BUNDLE_ID='com.oz.fitness.FitnessTracker'
DERIVED_DATA_PATH='.build/ios-simulator-derived-data'
OUT_DIR='artifacts/simulator-screenshots'
STAMP="$(date +%Y%m%d_%H%M%S)"
SHOT_PATH="$OUT_DIR/${STAMP}_deeplink.png"

mkdir -p "$OUT_DIR"

# Prefer a booted iPhone simulator; otherwise pick the first available iPhone simulator.
DEVICE_ID="$(xcrun simctl list devices available | awk '
  /iPhone/ && /Booted/ { id=$(NF-1); gsub(/[()]/, "", id); print id; exit }
')"
if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID="$(xcrun simctl list devices available | awk '
    /iPhone/ && /Shutdown/ { id=$(NF-1); gsub(/[()]/, "", id); print id; exit }
  ')"
fi

xcodebuild -project FitnessTracker.xcodeproj \
  -scheme FitnessTracker \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/FitnessTracker.app"

xcrun simctl boot "$DEVICE_ID" || true
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" || true
sleep 2
xcrun simctl openurl "$DEVICE_ID" "$DEEPLINK"
sleep 2
xcrun simctl io "$DEVICE_ID" screenshot "$SHOT_PATH"

printf 'SCREENSHOT_PATH=%s\n' "$SHOT_PATH"
```

## Notes
- `simctl` cannot tap app UI. Use `XCUITest` for deterministic UI interaction.
- This app defines `fitnesstracker` in `FitnessTracker/Info.plist` (`CFBundleURLTypes`).
- Device-name defaults are brittle across Xcode/runtime versions. Prefer simulator UDID.
- Use `-parallel-testing-enabled NO` to reduce flaky clone-device behavior.

## Troubleshooting
- Script missing: use manual fallback.
- Device not found: run `xcrun simctl list devices available` and choose an iPhone UDID.
- Test runner launch denied: boot one explicit simulator UDID and rerun with `-parallel-testing-enabled NO`.
- Launch fails: verify bundle ID (`com.oz.fitness.FitnessTracker`).
- URL opens but navigation does not change: route handler likely does not match deeplink path.
