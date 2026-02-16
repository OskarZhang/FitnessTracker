#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APPIUM_DIR="$ROOT_DIR/appium"
DERIVED_DATA_PATH="$ROOT_DIR/.build/ios-simulator-derived-data"
BUNDLE_ID="${IOS_BUNDLE_ID:-com.oz.fitness.FitnessTracker}"

if [[ ! -d "$APPIUM_DIR/node_modules" ]]; then
  echo "Installing Appium test dependencies..."
  (cd "$APPIUM_DIR" && npm install)
fi

if [[ -z "${IOS_SIM_UDID:-}" ]]; then
  IOS_SIM_UDID="$(xcrun simctl list devices available | awk '
    /iPhone/ && /Booted/ { id=$(NF-1); gsub(/[()]/, "", id); print id; exit }
  ')"
fi
if [[ -z "${IOS_SIM_UDID:-}" ]]; then
  IOS_SIM_UDID="$(xcrun simctl list devices available | awk '
    /iPhone/ && /Shutdown/ { id=$(NF-1); gsub(/[()]/, "", id); print id; exit }
  ')"
fi
if [[ -z "${IOS_SIM_UDID:-}" ]]; then
  echo "No available iPhone simulator found."
  exit 1
fi

echo "Using simulator UDID: $IOS_SIM_UDID"

xcrun simctl boot "$IOS_SIM_UDID" || true
xcrun simctl bootstatus "$IOS_SIM_UDID" -b

xcodebuild -project "$ROOT_DIR/FitnessTracker.xcodeproj" \
  -scheme FitnessTracker \
  -configuration Debug \
  -destination "id=$IOS_SIM_UDID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

IOS_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/FitnessTracker.app"
if [[ ! -d "$IOS_APP_PATH" ]]; then
  echo "Built app not found at $IOS_APP_PATH"
  exit 1
fi

xcrun simctl install "$IOS_SIM_UDID" "$IOS_APP_PATH"

APPIUM_LOG="$ROOT_DIR/artifacts/appium-server.log"
mkdir -p "$ROOT_DIR/artifacts"

(cd "$APPIUM_DIR" && npx appium --address 127.0.0.1 --port 4723 > "$APPIUM_LOG" 2>&1) &
APPIUM_PID=$!
cleanup() {
  kill "$APPIUM_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 4

(
  cd "$APPIUM_DIR"
  IOS_SIM_UDID="$IOS_SIM_UDID" \
  IOS_APP_PATH="$IOS_APP_PATH" \
  IOS_BUNDLE_ID="$BUNDLE_ID" \
  npm run test:ios
)
