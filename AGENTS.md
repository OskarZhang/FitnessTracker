# AGENTS.md

## Project Notes
- Add workout flow: `AddWorkoutView` drives navigation; `AddWorkoutViewModel` selects exercise and creates `SetLoggingViewModel` when logging starts.
- Set logging UI: `SetLoggingView` is the shared add/edit UI; logic lives in `SetLoggingViewModel` with `SetLoggingMode` (`.add`/`.edit`).
- Persistence: pending set-logging sessions for brand-new exercises are stored via `SetLoggingSessionStore` in `UserDefaults` and auto-restored from `ExercisesListView`.
- Editing: `WorkoutDetailView` has an Edit button that navigates to `SetLoggingView` in `.edit` mode.
- Data layer: `ExerciseService` owns SwiftData storage; use `addExercise` and `updateExercise` for saves.

## Core Architecture
- App entry: `FitnessTrackerApp` registers `ExerciseService` and `HealthKitManager` in `Container`.
- Root UI: onboarding is shown when `hasCompletedOnboarding == false` (except in UI-test sessions), otherwise `ExercisesListView`.
- Accent color: app-wide tint comes from `@AppStorage(AppAccentColor.storageKey)` and is applied to SwiftUI `.tint(...)` + UINavigationBar appearance.
- Home screen: `ExercisesListView` owns sheet presentation for Add Workout and Settings, grouped workout list rendering, deeplink routing, and empty state.

## Add + Save Flow
- `ExercisesListView` presents `AddWorkoutView(isPresented:)` in a sheet.
- `ExercisePickerView` writes to `AddWorkoutViewModel.selectedExercise`.
- `AddWorkoutViewModel` reacts to non-empty `selectedExercise` and starts set logging by creating `SetLoggingViewModel(mode: .add(...))`.
- `SetLoggingViewModel.saveWorkout()` persists only completed sets (`isCompleted == true`) through `ExerciseService.addExercise`.
- After save in add mode, `SetLoggingSessionStore.clear()` is called to remove pending session + restore flag.

## State Restoration Contract
- `SetLoggingSessionStore` keys:
- `pendingSetLoggingSession`
- `pendingSetLoggingSession.restoreOnNextLaunch`
- Restore must be explicit, not inferred by pending-session existence alone.
- Restore is triggered by `SetLoggingSessionStore.requestRestoreOnNextLaunch()` and consumed one-shot by `consumeRestoreRequest()`.
- `AddWorkoutViewModel.restorePendingSessionIfNeeded()` only restores when `consumeRestoreRequest()` returns true.
- Home auto-open restore behavior is gated by `SetLoggingSessionStore.shouldRestoreOnNextLaunch`.
- `SetLoggingView` persists pending state and requests restore intent on app phase changes to `.inactive`/`.background`.
- Restore intent ownership is single-source: only `SetLoggingView` requests restore token after a successful add-session persist.
- `FitnessTrackerApp` tracks phase transitions and clears restore request when app returns `.active` in the same process.
- Manual add entry points must clear restore intent first so user always sees picker:
- floating add button (`AddExerciseButton`)
- empty-state CTA
- deeplink `fitnesstracker://add`

## Known Bug Pattern (Critical)
- If restore intent is not cleared on manual add entry, users can get stuck reopening last logged exercise screen.
- If restore intent is cleared too aggressively during launch transitions, kill-restore may fail.
- Safe rule: restore only via one-shot token, and clear token on explicit user-driven add entry.

## UI Test Knowledge
- Preferred verification path: `FitnessTrackerUITests` on simulator (not deeplink-only).
- Main tests:
- `testAddWorkoutFlow`
- `testRestoresPendingSessionAfterBackgroundKill`
- Important launch args:
- `UI_TEST_RESET` resets app data through `ExerciseService(resetData: true)` and clears pending restore session.
- First-time AI onboarding prompt can block tests; dismiss via `setLogging.skipOnboardingButton` helper logic.
- Key accessibility IDs:
- `home.addWorkoutButton`
- `addWorkout.exerciseInput`
- `addWorkout.suggestion.<ExerciseName>`
- `setLogging.addSetButton`
- `setLogging.completeSetButton.<index>`
- `setLogging.saveButton`
- `home.emptyStateText`

## Deeplink Map
- Defined in `ExercisesListView` via `DeepLinkTarget`.
- Supported:
- `fitnesstracker://home`
- `fitnesstracker://add`
- `fitnesstracker://settings`
- `fitnesstracker://workout/<id>`
- `fitnesstracker://workout/latest`
- `fitnesstracker://workout/<id>/edit`

## Simulator/Verification Workflow
- Use skill: `fitnesstracker-ios-sim-flow`.
- Repo-local skill path: `skills/fitnesstracker-ios-sim-flow/SKILL.md` (use this copy for this repository).
- Default order:
- run targeted UI tests first
- run deeplink/screenshot flow only for additional visual validation
- Simctl cannot tap app UI; use XCUITest for deterministic interactions.
- Mandatory after any code change:
- always run `fitnesstracker-ios-sim-flow` to verify implementation
- compare the resulting UI screenshot(s) against the pre-change UI image(s)
- report concrete visual diffs (or explicitly state no visual change)
- run an independent sub-agent review of the produced screenshot(s) after each code change
- require the sub-agent to return a pass/fail design judgment and concise rationale
- if sub-agent result is fail, iterate on code + screenshot capture + sub-agent review until pass (or document explicit blocker)
