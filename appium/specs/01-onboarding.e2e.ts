import { expect } from '@wdio/globals';
import { relaunchApp, clickWhenPresent, waitForPresent } from '../support/appLifecycle';
import { a11y, ids } from '../support/selectors';

describe('Onboarding Flow', () => {
  it('shows onboarding on forced first launch and allows skipping to home', async () => {
    await relaunchApp(['INT_TEST_RESET_DATA', 'INT_TEST_FORCE_ONBOARDING']);

    await waitForPresent(a11y(ids.onboarding.title));
    await waitForPresent(a11y(ids.onboarding.notNowButton));
    await clickWhenPresent(a11y(ids.onboarding.notNowButton));

    const homeButton = await $(a11y(ids.home.addWorkoutButton));
    const reachedHome = await homeButton.waitForExist({ timeout: 10000 }).catch(() => false);
    if (!reachedHome) {
      const notNowAgain = await $(a11y(ids.onboarding.notNowButton));
      if (await notNowAgain.isExisting().catch(() => false)) {
        await notNowAgain.click();
      }
    }

    await expect(await waitForPresent(a11y(ids.home.addWorkoutButton), 20000)).toBeExisting();
  });
});
