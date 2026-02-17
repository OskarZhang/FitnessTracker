import { expect } from '@wdio/globals';
import {
  backgroundApp,
  clickWhenPresent,
  openDeepLink,
  relaunchApp,
  typeWhenPresent,
  waitForPresent,
} from '../support/appLifecycle';
import { a11y, ids } from '../support/selectors';

describe('Live Activity Resume Behavior', () => {
  it('does not change navigation when returning via active live activity in same process', async () => {
    await relaunchApp([
      'INT_TEST_RESET_DATA',
      'INT_TEST_COMPLETE_ONBOARDING',
      'UI_TEST_SKIP_FIRST_TIME_PROMPT',
    ]);

    await clickWhenPresent(a11y(ids.home.addWorkoutButton));
    await typeWhenPresent(a11y(ids.addWorkout.exerciseInput), 'Bench Press');
    await clickWhenPresent(a11y(ids.addWorkout.suggestion('Bench Press')));
    await waitForPresent(a11y(ids.setLogging.addSetButton));

    await clickWhenPresent(a11y(ids.setLogging.addSetButton));
    await waitForPresent(a11y(ids.setLogging.saveButton));

    await backgroundApp(1);
    await openDeepLink('fitnesstracker://live?exercise=Bench%20Press&state=activeLogging');

    await expect(await waitForPresent(a11y(ids.setLogging.saveButton))).toBeExisting();

    const promptSuggest = await $(a11y(ids.livePrompt.suggestNextButton));
    const promptEnd = await $(a11y(ids.livePrompt.endWorkoutButton));
    await expect(await promptSuggest.isExisting()).toBe(false);
    await expect(await promptEnd.isExisting()).toBe(false);
  });
});
