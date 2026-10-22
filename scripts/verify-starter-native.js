'use strict';

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const pkg = require(path.join(root, 'package.json'));
const prohibitedDependencies = [
  'firebase',
  '@react-native-google-signin/google-signin',
  'expo-auth-session',
  'expo-location',
  'expo-maps',
  'expo-widgets',
];

const expectedVersions = {
  expo: '~58.0.12',
  'react-native-screens': '4.30.0',
  '@expo/ui': '~58.0.19',
};

function fail(message) {
  console.error('Starter native verification failed: ' + message);
  process.exitCode = 1;
}

for (const name of prohibitedDependencies) {
  if (pkg.dependencies?.[name] || pkg.devDependencies?.[name]) {
    fail('prohibited app-specific dependency is present: ' + name);
  }
}

for (const [name, version] of Object.entries(expectedVersions)) {
  if (pkg.dependencies?.[name] !== version) {
    fail(name + ' must remain pinned to ' + version);
  }
}

const checks = [
  ['src/app/(tabs)/_layout.tsx', 'expo-router/native-tabs'],
  ['plugins/withStarterToolbarSync.js', 'StarterToolbarMorphExperimentVariant'],
  ['scripts/patch-expo-ui-bottom-sheet.js', 'ignoresSafeArea(.container, edges: .bottom)'],
  ['.github/workflows/swift-preflight.yml', 'CODE_SIGNING_ALLOWED=NO'],
  ['.github/workflows/native-sim.yml', 'native-sim-template-version: 18'],
];

for (const [relativePath, marker] of checks) {
  const filePath = path.join(root, relativePath);
  if (!fs.existsSync(filePath) || !fs.readFileSync(filePath, 'utf8').includes(marker)) {
    fail('missing expected native contract: ' + relativePath);
  }
}

const appConfigPath = path.join(root, 'app.config.js');
const starterProjectId = process.env.STARTER_EAS_PROJECT_ID;
delete process.env.STARTER_EAS_PROJECT_ID;
delete require.cache[require.resolve(appConfigPath)];
const resolvedAppConfig = require(appConfigPath).expo;
if (resolvedAppConfig.extra?.eas?.projectId) {
  fail('app.config.js must remain unlinked until a Starter-owned EAS project is configured explicitly');
}
if (/firebase|google-signin/i.test(fs.readFileSync(appConfigPath, 'utf8'))) {
  fail('app.config.js contains a removed service');
}
if (starterProjectId !== undefined) process.env.STARTER_EAS_PROJECT_ID = starterProjectId;

console.log('Starter native contracts are present.');
