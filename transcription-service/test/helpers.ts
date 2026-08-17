import type { Config } from '../src/config.js';
import { buildServer, type Deps } from '../src/server.js';
import { DevBypassVerifier } from '../src/security/attestation.js';
import { InMemoryRateLimiter } from '../src/security/rateLimit.js';
import { FakeTranscriptionProvider } from '../src/services/fakeTranscription.js';
import type { TranscriptionProvider } from '../src/services/transcription.js';

export function testConfig(overrides: Partial<Config> = {}): Config {
  return {
    NODE_ENV: 'test',
    PORT: 0,
    OPENAI_API_KEY: undefined,
    TRANSCRIBE_MODEL: 'gpt-transcribe',
    MAX_AUDIO_BYTES: 1024, // small, so oversized tests are cheap
    MAX_DURATION_SECONDS: 600,
    RATE_LIMIT_MAX: 3,
    RATE_LIMIT_WINDOW_SECONDS: 60,
    APP_ATTEST_REQUIRED: false,
    ...overrides,
  };
}

export function buildTestServer(opts: {
  config?: Partial<Config>;
  provider?: TranscriptionProvider;
  deps?: Partial<Deps>;
} = {}) {
  const config = testConfig(opts.config);
  const deps: Deps = {
    config,
    provider: opts.provider ?? new FakeTranscriptionProvider(),
    verifier: opts.deps?.verifier ?? new DevBypassVerifier(),
    limiter:
      opts.deps?.limiter ??
      new InMemoryRateLimiter(config.RATE_LIMIT_MAX, config.RATE_LIMIT_WINDOW_SECONDS * 1000),
  };
  return buildServer(deps);
}

/** Build a minimal multipart body with a single audio file part. */
export function multipartAudio(
  bytes: Buffer,
  { filename = 'note.m4a', contentType = 'audio/m4a' } = {},
): { payload: Buffer; headers: Record<string, string> } {
  const boundary = '----yourlytest' + Math.random().toString(16).slice(2);
  const head =
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="audio"; filename="${filename}"\r\n` +
    `Content-Type: ${contentType}\r\n\r\n`;
  const tail = `\r\n--${boundary}--\r\n`;
  const payload = Buffer.concat([Buffer.from(head), bytes, Buffer.from(tail)]);
  return {
    payload,
    headers: { 'content-type': `multipart/form-data; boundary=${boundary}` },
  };
}
