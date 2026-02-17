export const ids = {
  home: {
    addWorkoutButton: 'home.addWorkoutButton',
    emptyStateText: 'home.emptyStateText',
    settingsButton: 'home.settingsButton',
    workoutRow: (name: string) => `home.workoutRow.${name}`,
  },
  addWorkout: {
    exerciseInput: 'addWorkout.exerciseInput',
    suggestion: (name: string) => `addWorkout.suggestion.${name}`,
  },
  setLogging: {
    addSetButton: 'setLogging.addSetButton',
    saveButton: 'setLogging.saveButton',
    completeSetButton: (index: number) => `setLogging.completeSetButton.${index}`,
    aiEmptyStateText: 'setLogging.aiEmptyStateText',
    aiEmptyStateGenerateButton: 'setLogging.aiEmptyStateGenerateButton',
    aiToolbarButton: 'setLogging.aiToolbarButton',
    timerButton: 'setLogging.timerButton',
    timerCountdownLabel: 'setLogging.timerCountdownLabel',
  },
  onboarding: {
    title: 'onboarding.title',
    message: 'onboarding.message',
    enableHealthKitButton: 'onboarding.enableHealthKitButton',
    notNowButton: 'onboarding.notNowButton',
    healthkitMessage: 'onboarding.healthkitMessage',
  },
  settings: {
    healthkitStatusLabel: 'settings.healthkitStatusLabel',
    enableHealthKitButton: 'settings.enableHealthKitButton',
    exportWorkoutButton: 'settings.exportWorkoutButton',
    doneButton: 'settings.doneButton',
  },
  livePrompt: {
    suggestNextButton: 'livePrompt.suggestNextButton',
    endWorkoutButton: 'livePrompt.endWorkoutButton',
  },
};

export const a11y = (id: string): string => `~${id}`;
