const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

describe('Starter template boundary', () => {
  const packageJson = require(path.join(root, 'package.json'));

  test('uses Expo SDK 58 and Native Screens 4.30.0', () => {
    expect(packageJson.dependencies.expo).toBe('~58.0.12');
    expect(packageJson.dependencies['react-native-screens']).toBe('4.30.0');
  });

  test('has no business service dependencies', () => {
    expect(packageJson.dependencies).not.toHaveProperty('firebase');
    expect(packageJson.dependencies).not.toHaveProperty('@react-native-google-signin/google-signin');
    expect(packageJson.dependencies).not.toHaveProperty('expo-auth-session');
  });

  test('uses the stable SDK 58 native tabs module', () => {
    const tabsLayout = fs.readFileSync(path.join(root, 'src/app/(tabs)/_layout.tsx'), 'utf8');
    expect(tabsLayout).toContain('expo-router/native-tabs');
    expect(tabsLayout).not.toContain('unstable-native-tabs');
    for (const route of ['index.tsx', 'collections.tsx', 'search.tsx', 'settings.tsx']) {
      expect(fs.existsSync(path.join(root, 'src/app/(tabs)', route))).toBe(true);
    }
  });

  test('uses a dedicated opt-in variable for Starter EAS project linking', () => {
    const configPath = path.join(root, 'app.config.js');
    const appConfigSource = fs.readFileSync(configPath, 'utf8');
    expect(appConfigSource).toContain('process.env.STARTER_EAS_PROJECT_ID');
    expect(appConfigSource).not.toMatch(/process\.env\.EAS_PROJECT_ID\b/);
  });
});
