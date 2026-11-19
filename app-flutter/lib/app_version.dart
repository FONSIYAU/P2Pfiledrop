/// Single source of truth for display version strings across UI and About dialog.
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0',
);
const String kAppVersionTag = 'v$kAppVersion';
