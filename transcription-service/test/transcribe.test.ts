import { describe, it, expect } from 'vitest';
import { buildTestServer, multipartAudio } from './helpers.js';
import { FakeTranscriptionProvider } from '../src/services/fakeTranscription.js';
import { EmptyTranscriptError } from '../src/services/transcription.js';
import { AppAttestVerifier } from '../src/security/attestation.js';
import { InMemoryRateLimiter } from '../src/security/rateLimit.js';

const audio = Buffer.from('fake-audio-bytes');

describe('GET /health', () => {
  it('reports ok', async () => {
    const app = await buildTestServer();
    const res = await app.inject({ method: 'GET', url: '/health' });
    expect(res.statusCode).toBe(200);
    expect(res.json().status).toBe('ok');
    await app.close();
  });
});

describe('POST /v1/transcriptions', () => {
  it('returns a transcript with the fake provider', async () => {
    const app = await buildTestServer();
    const { payload, headers } = multipartAudio(audio);
    const res = await app.inject({ method: 'POST', url: '/v1/transcriptions', payload, headers });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body).toHaveProperty('requestId');
    expect(body.text).toContain('Anchorage');
    expect(body.languages).toEqual(['te', 'en']);
    await app.close();
  });

  it('echoes the client request id', async () => {
    const app = await buildTestServer();
    const { payload, headers } = multipartAudio(audio);
    const res = await app.inject({
      method: 'POST',
      url: '/v1/transcriptions',
      payload,
      headers: { ...headers, 'x-request-id': 'abc-123' },
    });
    expect(res.json().requestId).toBe('abc-123');
    await app.close();
  });

  it('rejects unsupported media types with 415', async () => {
    const app = await buildTestServer();
    const { payload, headers } = multipartAudio(audio, { contentType: 'text/plain' });
    const res = await app.inject({ method: 'POST', url: '/v1/transcriptions', payload, headers });
    expect(res.statusCode).toBe(415);
    await app.close();
  });

  it('rejects oversized audio with 413', async () => {
    const app = await buildTestServer({ config: { MAX_AUDIO_BYTES: 8 } });
    const { payload, headers } = multipartAudio(Buffer.alloc(64, 1));
    const res = await app.inject({ method: 'POST', url: '/v1/transcriptions', payload, headers });
    expect(res.statusCode).toBe(413);
    await app.close();
  });

  it('maps empty transcripts to 422 no_speech', async () => {
    const app = await buildTestServer({
      provider: new FakeTranscriptionProvider(undefined, new EmptyTranscriptError()),
    });
    const { payload, headers } = multipartAudio(audio);
    const res = await app.inject({ method: 'POST', url: '/v1/transcriptions', payload, headers });
    expect(res.statusCode).toBe(422);
    expect(res.json().error).toBe('no_speech');
    await app.close();
  });

  it('rate limits after the configured max (429)', async () => {
    const app = await buildTestServer({
      deps: { limiter: new InMemoryRateLimiter(1, 60_000) },
    });
    const first = await app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(audio) });
    const second = await app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(audio) });
    expect(first.statusCode).toBe(200);
    expect(second.statusCode).toBe(429);
    await app.close();
  });

  it('requires attestation when configured (401)', async () => {
    const app = await buildTestServer({
      config: { APP_ATTEST_REQUIRED: true },
      deps: { verifier: new AppAttestVerifier('ABCDE12345.com.astold.app') },
    });
    const { payload, headers } = multipartAudio(audio);
    const res = await app.inject({ method: 'POST', url: '/v1/transcriptions', payload, headers });
    expect(res.statusCode).toBe(401);
    expect(res.json().error).toBe('attestation_failed');
    await app.close();
  });
});
