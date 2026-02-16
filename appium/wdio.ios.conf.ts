import type { Options } from '@wdio/types';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '..');
const defaultAppPath = path.join(
  repoRoot,
  '.build/ios-simulator-derived-data/Build/Products/Debug-iphonesimulator/FitnessTracker.app',
);

export const config: Options.Testrunner = {
  runner: 'local',
  tsConfigPath: path.join(__dirname, 'tsconfig.json'),
  specs: ['./specs/**/*.e2e.ts'],
  maxInstances: 1,
  logLevel: 'info',
  framework: 'mocha',
  mochaOpts: {
    timeout: 120000,
  },
  reporters: ['spec'],
  hostname: '127.0.0.1',
  port: 4723,
  path: '/',
  waitforTimeout: 15000,
  connectionRetryTimeout: 120000,
  connectionRetryCount: 1,
  capabilities: [
    {
      platformName: 'iOS',
      'appium:automationName': 'XCUITest',
      'appium:deviceName': process.env.IOS_DEVICE_NAME ?? 'iPhone 17 Pro',
      'appium:platformVersion': process.env.IOS_PLATFORM_VERSION,
      'appium:udid': process.env.IOS_SIM_UDID,
      'appium:app': process.env.IOS_APP_PATH ?? defaultAppPath,
      'appium:bundleId': process.env.IOS_BUNDLE_ID ?? 'com.oz.fitness.FitnessTracker',
      'appium:noReset': false,
      'appium:fullReset': false,
      'appium:newCommandTimeout': 120,
      'appium:autoAcceptAlerts': true,
    },
  ],
  services: [],
};

export default config;
