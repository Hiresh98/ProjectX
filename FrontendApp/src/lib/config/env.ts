/**
 * Centralized, validated access to runtime configuration.
 *
 * Reading `import.meta.env` directly across the codebase is an anti-pattern:
 * it scatters string literals, bypasses validation, and makes mocking in tests
 * harder. Instead, all environment access funnels through this typed module,
 * which fails fast at startup if required variables are missing.
 */

interface AppConfig {
  readonly apiBaseUrl: string;
  readonly appName: string;
  readonly isProduction: boolean;
  readonly isDevelopment: boolean;
}

function requireEnv(key: keyof ImportMetaEnv): string {
  const value = import.meta.env[key];
  if (value === undefined || value === '') {
    throw new Error(
      `[config] Missing required environment variable: ${String(key)}. ` +
        `Did you copy .env.example to .env?`,
    );
  }
  return value;
}

export const config: AppConfig = {
  apiBaseUrl: requireEnv('VITE_API_BASE_URL'),
  appName: requireEnv('VITE_APP_NAME'),
  isProduction: import.meta.env.PROD,
  isDevelopment: import.meta.env.DEV,
};
