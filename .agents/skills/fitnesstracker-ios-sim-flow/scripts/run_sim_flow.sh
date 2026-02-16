#!/usr/bin/env bash
set -euo pipefail

PROJECT="FitnessTracker.xcodeproj"
SCHEME="FitnessTracker"
DEVICE_NAME=""
DEVICE_UDID=""
CONFIGURATION="Debug"
OUTPUT_DIR="artifacts/simulator-screenshots"
SCREENSHOT_NAME=""
DERIVED_DATA_PATH=".build/ios-simulator-derived-data"
UI_TEST_IDENTIFIER="FitnessTrackerUITests/FitnessTrackerUITests/testCaptureSetLoggingEmptyStateScreenshot"

usage() {
  cat <<USAGE
Usage:
  scripts/run_sim_flow.sh [options]

Options:
  --ui-test <identifier>       XCUITest identifier (default: ${UI_TEST_IDENTIFIER})
  --project <path>             Xcode project path (default: ${PROJECT})
  --scheme <name>              Xcode scheme (default: ${SCHEME})
  --device <name>              Simulator device name (auto-select if omitted)
  --udid <id>                  Simulator UDID (overrides --device)
  --configuration <name>       Build configuration (default: ${CONFIGURATION})
  --output-dir <dir>           Screenshot output directory (default: ${OUTPUT_DIR})
  --screenshot-name <name>     Screenshot filename (default: <timestamp>_xcuitest.png)
  --derived-data-path <dir>    DerivedData location (default: ${DERIVED_DATA_PATH})
  --help                       Show this help
USAGE
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ui-test)
      [[ $# -ge 2 ]] || die "Missing value for --ui-test"
      UI_TEST_IDENTIFIER="$2"
      shift 2
      ;;
    --project)
      [[ $# -ge 2 ]] || die "Missing value for --project"
      PROJECT="$2"
      shift 2
      ;;
    --scheme)
      [[ $# -ge 2 ]] || die "Missing value for --scheme"
      SCHEME="$2"
      shift 2
      ;;
    --device)
      [[ $# -ge 2 ]] || die "Missing value for --device"
      DEVICE_NAME="$2"
      shift 2
      ;;
    --udid)
      [[ $# -ge 2 ]] || die "Missing value for --udid"
      DEVICE_UDID="$2"
      shift 2
      ;;
    --configuration)
      [[ $# -ge 2 ]] || die "Missing value for --configuration"
      CONFIGURATION="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || die "Missing value for --output-dir"
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --screenshot-name)
      [[ $# -ge 2 ]] || die "Missing value for --screenshot-name"
      SCREENSHOT_NAME="$2"
      shift 2
      ;;
    --derived-data-path)
      [[ $# -ge 2 ]] || die "Missing value for --derived-data-path"
      DERIVED_DATA_PATH="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

require_cmd xcodebuild
require_cmd xcrun
require_cmd awk
require_cmd sed
require_cmd date

[[ -d "$PROJECT" || -f "$PROJECT" ]] || die "Project not found: $PROJECT"
[[ -n "$UI_TEST_IDENTIFIER" ]] || die "--ui-test cannot be empty"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$DERIVED_DATA_PATH"

if [[ -n "$DEVICE_UDID" ]]; then
  DEVICE_LINE="$(xcrun simctl list devices available | awk -v udid="$DEVICE_UDID" 'index($0, "(" udid ")") {print; exit}')"
else
  if [[ -n "$DEVICE_NAME" ]]; then
    DEVICE_LINE="$(xcrun simctl list devices available | awk -v name="$DEVICE_NAME" 'index($0, name " (") {print; exit}')"
  else
    DEVICE_LINE="$(xcrun simctl list devices available | awk '
      /iPhone/ && /Booted/ { print; exit }
      END { if (!NR) exit 1 }
    ')"
    if [[ -z "$DEVICE_LINE" ]]; then
      DEVICE_LINE="$(xcrun simctl list devices available | awk '
        /iPhone/ && /Shutdown/ { print; exit }
      ')"
    fi
  fi
fi
[[ -n "${DEVICE_LINE:-}" ]] || die "No matching available iPhone simulator found"

DEVICE_UDID="$(echo "$DEVICE_LINE" | awk 'match($0, /[0-9A-Fa-f-]{36}/) { print substr($0, RSTART, RLENGTH); exit }')"
[[ -n "$DEVICE_UDID" ]] || die "Could not parse simulator UDID"

DEVICE_STATE="$(echo "$DEVICE_LINE" | sed -E 's/.*\([A-Za-z0-9-]+\) \(([^)]+)\).*/\1/')"

if [[ "$DEVICE_STATE" != "Booted" ]]; then
  echo "[INFO] Booting simulator: $DEVICE_UDID"
  xcrun simctl boot "$DEVICE_UDID" >/dev/null 2>&1 || true
fi

xcrun simctl bootstatus "$DEVICE_UDID" -b

if [[ -z "$SCREENSHOT_NAME" ]]; then
  SCREENSHOT_NAME="$(date +%Y%m%d-%H%M%S)_xcuitest.png"
fi

SCREENSHOT_PATH="$OUTPUT_DIR/$SCREENSHOT_NAME"
if [[ "$SCREENSHOT_PATH" = /* ]]; then
  ABS_SCREENSHOT_PATH="$SCREENSHOT_PATH"
else
  ABS_SCREENSHOT_PATH="$(pwd)/$SCREENSHOT_PATH"
fi
HOST_CAPTURE_PATH="/tmp/fitnesstracker-ui-test-screenshot.png"
rm -f "$HOST_CAPTURE_PATH"

echo "[INFO] Running XCUITest: $UI_TEST_IDENTIFIER"
UI_TEST_SCREENSHOT_PATH="$HOST_CAPTURE_PATH" \
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -parallel-testing-enabled NO \
  -only-testing:"$UI_TEST_IDENTIFIER" \
  test

[[ -s "$HOST_CAPTURE_PATH" ]] || die "Screenshot not generated at: $HOST_CAPTURE_PATH"
cp "$HOST_CAPTURE_PATH" "$ABS_SCREENSHOT_PATH"
[[ -s "$ABS_SCREENSHOT_PATH" ]] || die "Screenshot not generated at: $ABS_SCREENSHOT_PATH"
printf '[OK] Screenshot saved: %s\n' "$ABS_SCREENSHOT_PATH"
