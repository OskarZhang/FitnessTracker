---
name: fitnesstracker-ios-sim-flow
description: Build/test the active FitnessTracker iOS app in Simulator with XCUITest-driven navigation and screenshot capture.
---

# FitnessTracker iOS Sim Flow

## Overview
Use this skill to verify UI correctness in this repo. The default path is:
1. Run `FitnessTrackerUITests` on Simulator.
2. If visual evidence is needed, run the screenshot flow that drives the UI via XCUITest.

Use XCUITest as the single UI driver for both behavior validation and screenshot capture.

## Default Workflow (UI correctness)
1. Confirm you are in the `FitnessTracker` repo root.
2. Build + run targeted UI tests first.
3. Run screenshot capture flow if visual confirmation is needed.
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

For navigation-only coverage (no deeplink dependency), run:
```bash
xcodebuild -project FitnessTracker.xcodeproj \
  -scheme FitnessTracker \
  -destination 'id=<SIMULATOR_UDID>' \
  -parallel-testing-enabled NO \
  -only-testing:FitnessTrackerUITests/NavigationCoverageUITests/testNavigateHomeSettingsAddAndSetLoggingScreens \
  -only-testing:FitnessTrackerUITests/NavigationCoverageUITests/testNavigateWorkoutDetailAndEditSetLoggingScreens \
  test
```

For critical user-path coverage (onboarding, log exercise, timer, health settings), run:
```bash
xcodebuild -project FitnessTracker.xcodeproj \
  -scheme FitnessTracker \
  -destination 'id=<SIMULATOR_UDID>' \
  -parallel-testing-enabled NO \
  -only-testing:FitnessTrackerUITests/FitnessTrackerUITests/testAddWorkoutFlow \
  -only-testing:FitnessTrackerUITests/CriticalPathUITests/testOnboardingFlowSkipToHome \
  -only-testing:FitnessTrackerUITests/CriticalPathUITests/testTimerFlowStartsWhileLogging \
  -only-testing:FitnessTrackerUITests/CriticalPathUITests/testHealthKitSettingsFlowReachable \
  test
```

## XCUITest Screenshot Flow
If `scripts/run_sim_flow.sh` exists, run:
```bash
.agents/skills/fitnesstracker-ios-sim-flow/scripts/run_sim_flow.sh \
  --ui-test 'FitnessTrackerUITests/FitnessTrackerUITests/testCaptureSetLoggingEmptyStateScreenshot'
```

Optional flags:
- `--ui-test` (default `FitnessTrackerUITests/FitnessTrackerUITests/testCaptureSetLoggingEmptyStateScreenshot`)
- `--project` (default `FitnessTracker.xcodeproj`)
- `--scheme` (default `FitnessTracker`)
- `--device` (device name)
- `--udid` (simulator UDID, preferred for stability)
- `--configuration` (default `Debug`)
- `--output-dir` (default `artifacts/simulator-screenshots`)
- `--screenshot-name` (default `<timestamp>_xcuitest.png`)
- `--derived-data-path` (default `.build/ios-simulator-derived-data`)

## Manual Fallback (when script is missing)
Use this exact sequence:

```bash
set -euo pipefail
DERIVED_DATA_PATH='.build/ios-simulator-derived-data'
OUT_DIR='artifacts/simulator-screenshots'
STAMP="$(date +%Y%m%d_%H%M%S)"
SHOT_PATH="$OUT_DIR/${STAMP}_xcuitest.png"
UI_TEST='FitnessTrackerUITests/FitnessTrackerUITests/testCaptureSetLoggingEmptyStateScreenshot'
HOST_CAPTURE_PATH='/tmp/fitnesstracker-ui-test-screenshot.png'

mkdir -p "$OUT_DIR"
rm -f "$HOST_CAPTURE_PATH"

# Prefer a booted iPhone simulator; otherwise pick the first available iPhone simulator.
DEVICE_ID="$(xcrun simctl list devices available | awk '
  /iPhone/ && /Booted/ { id=$(NF-1); gsub(/[()]/, "", id); print id; exit }
')"
if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID="$(xcrun simctl list devices available | awk '
    /iPhone/ && /Shutdown/ { id=$(NF-1); gsub(/[()]/, "", id); print id; exit }
  ')"
fi

UI_TEST_SCREENSHOT_PATH="$HOST_CAPTURE_PATH" xcodebuild -project FitnessTracker.xcodeproj \
  -scheme FitnessTracker \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -parallel-testing-enabled NO \
  -only-testing:"$UI_TEST" \
  test
cp "$HOST_CAPTURE_PATH" "$SHOT_PATH"

printf 'SCREENSHOT_PATH=%s\n' "$SHOT_PATH"
```

## Notes
- Screenshot capture is driven by XCUITest method `testCaptureSetLoggingEmptyStateScreenshot`.
- The skill script writes to `/tmp/fitnesstracker-ui-test-screenshot.png` first, then copies to the requested output path.
- `simctl` cannot tap app UI, so the script uses XCTest automation to navigate before capture.
- Device-name selection can be brittle across Xcode/runtime versions. Prefer simulator UDID.
- Use `-parallel-testing-enabled NO` to reduce flaky clone-device behavior.

## Troubleshooting
- Script missing: use manual fallback.
- Device not found: run `xcrun simctl list devices available` and choose an iPhone UDID.
- Test runner launch denied: boot one explicit simulator UDID and rerun with `-parallel-testing-enabled NO`.
- Screenshot file missing: verify `/tmp/fitnesstracker-ui-test-screenshot.png` was created and can be copied to the output path.
