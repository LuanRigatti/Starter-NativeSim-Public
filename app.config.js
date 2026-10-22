const toolbarVariant = process.env.STARTER_TOOLBAR_MORPH_VARIANT === 'B' ? 'B' : 'A';
const starterEasProjectId = process.env.STARTER_EAS_PROJECT_ID;

if (
  starterEasProjectId &&
  !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(starterEasProjectId)
) {
  throw new Error('STARTER_EAS_PROJECT_ID must be a UUID for the independently created Starter EAS project.');
}

module.exports = {
  expo: {
    name: 'Starter',
    slug: 'starter',
    scheme: 'starter',
    version: '1.0.0',
    orientation: 'portrait',
    userInterfaceStyle: 'automatic',
    icon: './assets/icon.png',
    splash: {
      image: './assets/splash.png',
      resizeMode: 'contain',
      backgroundColor: '#F7F8FC',
    },
    ios: {
      bundleIdentifier: 'com.luanrigatti.starter',
      supportsTablet: true,
      deploymentTarget: '16.4',
      infoPlist: {
        StarterToolbarMorphExperimentVariant: toolbarVariant,
      },
    },
    android: {
      package: 'com.luanrigatti.starter',
      adaptiveIcon: {
        foregroundImage: './assets/adaptive-icon.png',
        backgroundColor: '#F7F8FC',
      },
    },
    plugins: [
      'expo-router',
      [
        'expo-splash-screen',
        {
          backgroundColor: '#F7F8FC',
          image: './assets/splash.png',
          imageWidth: 160,
          resizeMode: 'contain',
        },
      ],
      './plugins/withStarterToolbarSync',
    ],
    experiments: {
      typedRoutes: true,
    },
    extra: {
      starterTemplate: true,
      ...(starterEasProjectId ? { eas: { projectId: starterEasProjectId } } : {}),
    },
  },
};
