const BUNDLE_ID = process.env.IOS_BUNDLE_ID ?? 'com.oz.fitness.FitnessTracker';

export async function relaunchApp(args: string[] = []): Promise<void> {
  const terminateArgs = { bundleId: BUNDLE_ID };
  await browser.execute('mobile: terminateApp', terminateArgs).catch(() => undefined);

  const launchArgs = { bundleId: BUNDLE_ID, arguments: args };
  await browser.execute('mobile: launchApp', launchArgs);
}

export async function waitForPresent(selector: string, timeout = 10000): Promise<WebdriverIO.Element> {
  const el = await $(selector);
  await el.waitForExist({ timeout });
  return el;
}

export async function clickWhenPresent(selector: string, timeout = 10000): Promise<void> {
  const el = await waitForPresent(selector, timeout);
  await el.click();
}

export async function typeWhenPresent(selector: string, value: string, timeout = 10000): Promise<void> {
  const el = await waitForPresent(selector, timeout);
  await el.click();
  await el.setValue(value);
}

export function extractLeadingInt(value: string): number | null {
  const match = value.match(/(\d+)/);
  if (!match) {
    return null;
  }
  return Number(match[1]);
}
