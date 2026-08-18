import { describe, it, expect } from 'vitest';
import { loadConfig } from '../src/config.js';

/** Minimal env; each test adds only what it is about. */
const base = { PORT: '8787' } as NodeJS.ProcessEnv;

describe('loadConfig App Attest rails', () => {
  it('leaves development unprotected without ceremony', () => {
    expect(loadConfig({ ...base }).APP_ATTEST_REQUIRED).toBe(false);
  });

  it('refuses to start a production relay with attestation off', () => {
    expect(() =>
      loadConfig({ ...base, NODE_ENV: 'production', APP_ATTEST_REQUIRED: 'false' }),
    ).toThrow(/APP_ATTEST_REQUIRED/);
  });

  it('allows an unprotected production relay only when explicitly opted in', () => {
    const config = loadConfig({
      ...base,
      NODE_ENV: 'production',
      APP_ATTEST_REQUIRED: 'false',
      APP_ATTEST_ALLOW_UNPROTECTED: 'true',
    });
    expect(config.APP_ATTEST_REQUIRED).toBe(false);
  });

  it('refuses to enforce attestation without a durable key store path', () => {
    expect(() =>
      loadConfig({
        ...base,
        APP_ATTEST_REQUIRED: 'true',
        APP_ATTEST_APP_ID: 'ABCDE12345.com.astold.app',
      }),
    ).toThrow(/APP_ATTEST_DB_PATH/);
  });

  it('accepts enforcement when a key store path is given', () => {
    const config = loadConfig({
      ...base,
      NODE_ENV: 'production',
      APP_ATTEST_REQUIRED: 'true',
      APP_ATTEST_APP_ID: 'ABCDE12345.com.astold.app',
      APP_ATTEST_DB_PATH: '/data/app-attest.db',
    });
    expect(config.APP_ATTEST_DB_PATH).toBe('/data/app-attest.db');
  });
});
