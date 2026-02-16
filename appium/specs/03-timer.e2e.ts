import { expect } from '@wdio/globals';
import {
  relaunchApp,
  clickWhenPresent,
  extractLeadingInt,
  typeWhenPresent,
  waitForPresent,
} from '../support/appLifecycle';
import { a11y, ids } from '../support/selectors';

async function dismissSetLoggingOnboardingIfPresent(): Promise<void> {
  const skipButton = await $(a11y(ids.setLogging.skipOnboardingButton));
  if (await skipButton.isExisting().catch(() => false)) {
    await skipButton.click();
  }
}

describe('Set Logging Timer', () => {
  it('starts and counts down while logging', async () => {
    await relaunchApp([
      'INT_TEST_RESET_DATA',
      'INT_TEST_COMPLETE_ONBOARDING',
      'UI_TEST_SKIP_FIRST_TIME_PROMPT',
    ]);

    await clickWhenPresent(a11y(ids.home.addWorkoutButton));
    await typeWhenPresent(a11y(ids.addWorkout.exerciseInput), 'Bench Press');
    await clickWhenPresent(a11y(ids.addWorkout.suggestion('Bench Press')));

    await dismissSetLoggingOnboardingIfPresent();
    await clickWhenPresent(a11y(ids.setLogging.addSetButton));
    await clickWhenPresent(a11y(ids.setLogging.timerButton));
    await browser.pause(300);
    await clickWhenPresent(a11y(ids.setLogging.timerButton));

    const timerButton = await waitForPresent(a11y(ids.setLogging.timerButton));
    await browser.waitUntil(async () => {
      const label = (await timerButton.getAttribute('label')) ?? '';
      return extractLeadingInt(label) !== null;
    }, { timeout: 6000, interval: 250, timeoutMsg: 'Timer did not start' });

    const firstValue = extractLeadingInt((await timerButton.getAttribute('label')) ?? '');

    expect(firstValue).not.toBeNull();
  });
});
