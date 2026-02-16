import { expect } from '@wdio/globals';
import { relaunchApp, clickWhenPresent, waitForPresent } from '../support/appLifecycle';
import { a11y, ids } from '../support/selectors';

describe('Onboarding Flow', () => {
  it('shows onboarding on forced first launch and allows skipping to home', async () => {
    await relaunchApp(['INT_TEST_RESET_DATA', 'INT_TEST_FORCE_ONBOARDING']);

    await waitForPresent(a11y(ids.onboarding.title));
    await waitForPresent(a11y(ids.onboarding.notNowButton));
    await clickWhenPresent(a11y(ids.onboarding.notNowButton));

    await expect(await waitForPresent(a11y(ids.home.addWorkoutButton))).toBeExisting();
  });
});
