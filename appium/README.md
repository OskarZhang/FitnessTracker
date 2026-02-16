# FitnessTracker Appium Integration Tests

This suite covers critical iOS user paths with Appium + WebdriverIO:

1. Onboarding flow.
2. Log a new exercise and verify persistence in the home list.
3. Timer countdown while logging sets.
4. HealthKit connection flow in simulator-safe mode.

## Prerequisites

- Xcode + iOS Simulator.
- Node.js 20+.
- Appium dependencies installed via `npm install`.

## Install

```bash
cd appium
npm install
```

## Run

Use the root helper script:

```bash
scripts/run_appium_critical_paths.sh
```

Optional environment variables:

- `IOS_SIM_UDID`: simulator UDID.
- `IOS_DEVICE_NAME`: simulator name (default: `iPhone 17 Pro`).
- `IOS_PLATFORM_VERSION`: iOS runtime version.
- `IOS_BUNDLE_ID`: bundle id (default: `com.oz.fitness.FitnessTracker`).
