# AGENTS.md

## Project Notes
- Add workout flow: `AddWorkoutView` drives navigation; `AddWorkoutViewModel` selects exercise and creates `SetLoggingViewModel` when logging starts.
- Set logging UI: `SetLoggingView` is the shared add/edit UI; logic lives in `SetLoggingViewModel` with `SetLoggingMode` (`.add`/`.edit`).
- Persistence: pending set-logging sessions for brand-new exercises are stored via `SetLoggingSessionStore` in `UserDefaults` and auto-restored from `ExercisesListView`.
- Editing: `WorkoutDetailView` has an Edit button that navigates to `SetLoggingView` in `.edit` mode.
- Data layer: `ExerciseService` owns SwiftData storage; use `addExercise` and `updateExercise` for saves.
