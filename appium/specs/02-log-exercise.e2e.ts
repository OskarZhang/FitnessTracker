import fs from 'node:fs';
import { expect } from '@wdio/globals';
import { relaunchApp, clickWhenPresent, typeWhenPresent, waitForPresent } from '../support/appLifecycle';
import { a11y, ids } from '../support/selectors';

describe('Log Exercise', () => {
  it('logs a new exercise and persists it to list view', async () => {
    fs.mkdirSync('../artifacts/designer/after', { recursive: true });

    await relaunchApp([
      'INT_TEST_RESET_DATA',
      'INT_TEST_COMPLETE_ONBOARDING',
      'UI_TEST_SKIP_FIRST_TIME_PROMPT',
    ]);

    await clickWhenPresent(a11y(ids.home.addWorkoutButton));
    await typeWhenPresent(a11y(ids.addWorkout.exerciseInput), 'Bench Press');
    await clickWhenPresent(a11y(ids.addWorkout.suggestion('Bench Press')));

    await expect(await waitForPresent(a11y(ids.setLogging.addSetButton))).toBeExisting();
    await browser.saveScreenshot('../artifacts/designer/after/after_setlogging_empty.png');
    await clickWhenPresent(a11y(ids.setLogging.addSetButton));
    await expect(await waitForPresent(a11y(ids.setLogging.saveButton))).toBeExisting();
    await browser.saveScreenshot('../artifacts/designer/after/after_setlogging_non_empty.png');
    await clickWhenPresent(a11y(ids.setLogging.saveButton));

    await expect(await waitForPresent(a11y(ids.home.workoutRow('Bench Press')))).toBeExisting();
  });
});
