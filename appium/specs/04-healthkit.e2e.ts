import { expect } from '@wdio/globals';
import { relaunchApp, clickWhenPresent, waitForPresent } from '../support/appLifecycle';
import { a11y, ids } from '../support/selectors';

const allowedStatusValues = new Set(['Unavailable', 'Not enabled', 'Authorized', 'Denied', 'Unknown']);

describe('HealthKit Connection Flow', () => {
  it('supports onboarding + settings healthkit path on simulator', async () => {
    await relaunchApp(['INT_TEST_RESET_DATA', 'INT_TEST_COMPLETE_ONBOARDING']);
    await waitForPresent(a11y(ids.home.addWorkoutButton));

    await clickWhenPresent(a11y(ids.home.settingsButton));

    const statusLabel = await waitForPresent(a11y(ids.settings.healthkitStatusLabel));
    const statusText = await statusLabel.getText();
    expect(allowedStatusValues.has(statusText)).toBe(true);

    const enableHealthKitButton = await $(a11y(ids.settings.enableHealthKitButton));
    if (await enableHealthKitButton.isExisting().catch(() => false)) {
      const isEnabled = await enableHealthKitButton.isEnabled();
      if (isEnabled) {
        await enableHealthKitButton.click();
        await browser.pause(1000);
      }
    }

    await clickWhenPresent(a11y(ids.settings.doneButton));
    await expect(await waitForPresent(a11y(ids.home.addWorkoutButton))).toBeExisting();
  });
});
