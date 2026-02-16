#!/usr/bin/env bash
set -euo pipefail

PROJECT="FitnessTracker.xcodeproj"
SCHEME="FitnessTracker"
DEVICE_NAME="iPhone 15"
CONFIGURATION="Debug"
BUNDLE_ID="com.oz.fitness.FitnessTracker"
OUTPUT_DIR="artifacts/simulator-screenshots"
SCREENSHOT_NAME=""
DERIVED_DATA_PATH=".build/ios-simulator-derived-data"
POST_LAUNCH_WAIT="2"
DEEPLINK_URL=""

usage() {
  cat <<USAGE
Usage:
  scripts/run_sim_flow.sh --deeplink <url> [options]

Required:
  --deeplink <url>             Deeplink URL to open in Simulator (e.g. myapp://route)

Options:
  --project <path>             Xcode project path (default: ${PROJECT})
  --scheme <name>              Xcode scheme (default: ${SCHEME})
  --device <name>              Simulator device name (default: ${DEVICE_NAME})
  --configuration <name>       Build configuration (default: ${CONFIGURATION})
  --bundle-id <id>             App bundle identifier (default: ${BUNDLE_ID})
  --output-dir <dir>           Screenshot output directory (default: ${OUTPUT_DIR})
  --screenshot-name <name>     Screenshot filename (default: <timestamp>_deeplink.png)
  --derived-data-path <dir>    DerivedData location (default: ${DERIVED_DATA_PATH})
  --post-launch-wait <secs>    Seconds to wait after launch (default: ${POST_LAUNCH_WAIT})
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
    --deeplink)
      [[ $# -ge 2 ]] || die "Missing value for --deeplink"
      DEEPLINK_URL="$2"
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
    --configuration)
      [[ $# -ge 2 ]] || die "Missing value for --configuration"
      CONFIGURATION="$2"
      shift 2
      ;;
    --bundle-id)
      [[ $# -ge 2 ]] || die "Missing value for --bundle-id"
      BUNDLE_ID="$2"
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
    --post-launch-wait)
      [[ $# -ge 2 ]] || die "Missing value for --post-launch-wait"
      POST_LAUNCH_WAIT="$2"
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

[[ -n "$DEEPLINK_URL" ]] || die "--deeplink is required"
[[ "$DEEPLINK_URL" =~ ^[A-Za-z][A-Za-z0-9+.-]*: ]] || die "--deeplink must be an absolute URL with a scheme"

require_cmd xcodebuild
require_cmd xcrun
require_cmd awk
require_cmd sed
require_cmd date

[[ -d "$PROJECT" || -f "$PROJECT" ]] || die "Project not found: $PROJECT"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$DERIVED_DATA_PATH"

DEVICE_LINE="$(xcrun simctl list devices available | awk -v name="$DEVICE_NAME" 'index($0, name " (") {print; exit}')"
[[ -n "$DEVICE_LINE" ]] || die "Simulator device not found: $DEVICE_NAME"

DEVICE_UDID="$(echo "$DEVICE_LINE" | sed -E 's/.*\(([A-Za-z0-9-]+)\).*/\1/')"
[[ -n "$DEVICE_UDID" ]] || die "Could not parse simulator UDID for device: $DEVICE_NAME"

DEVICE_STATE="$(echo "$DEVICE_LINE" | sed -E 's/.*\([A-Za-z0-9-]+\) \(([^)]+)\).*/\1/')"

if [[ "$DEVICE_STATE" != "Booted" ]]; then
  echo "[INFO] Booting simulator: $DEVICE_NAME ($DEVICE_UDID)"
  xcrun simctl boot "$DEVICE_UDID" >/dev/null 2>&1 || true
fi

xcrun simctl bootstatus "$DEVICE_UDID" -b

DESTINATION="platform=iOS Simulator,id=$DEVICE_UDID"

echo "[INFO] Building $SCHEME ($CONFIGURATION)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

BUILD_SETTINGS="$(xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -showBuildSettings)"

TARGET_BUILD_DIR="$(echo "$BUILD_SETTINGS" | awk -F ' = ' '/ TARGET_BUILD_DIR = / {print $2; exit}')"
FULL_PRODUCT_NAME="$(echo "$BUILD_SETTINGS" | awk -F ' = ' '/ FULL_PRODUCT_NAME = / {print $2; exit}')"

[[ -n "$TARGET_BUILD_DIR" ]] || die "Could not resolve TARGET_BUILD_DIR"
[[ -n "$FULL_PRODUCT_NAME" ]] || die "Could not resolve FULL_PRODUCT_NAME"

APP_PATH="$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
[[ -d "$APP_PATH" ]] || die "Built app not found at: $APP_PATH"

echo "[INFO] Installing app: $APP_PATH"
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[INFO] Launching app: $BUNDLE_ID"
xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null

sleep "$POST_LAUNCH_WAIT"

echo "[INFO] Opening URL: $DEEPLINK_URL"
xcrun simctl openurl "$DEVICE_UDID" "$DEEPLINK_URL"

if [[ -z "$SCREENSHOT_NAME" ]]; then
  SCREENSHOT_NAME="$(date +%Y%m%d-%H%M%S)_deeplink.png"
fi

SCREENSHOT_PATH="$OUTPUT_DIR/$SCREENSHOT_NAME"

echo "[INFO] Capturing screenshot: $SCREENSHOT_PATH"
xcrun simctl io "$DEVICE_UDID" screenshot "$SCREENSHOT_PATH"

printf '[OK] Screenshot saved: %s\n' "$SCREENSHOT_PATH"
