import { describe, it, expect } from 'vitest';
import { buildTestServer, captureLogs, multipartAudio } from './helpers.js';
import { adts, m4a, mp3, notAudio, validAudio, wav } from './fixtures.js';
import { FakeTranscriptionProvider } from '../src/services/fakeTranscription.js';
import { EmptyTranscriptError } from '../src/services/transcription.js';
import { AppAttestVerifier } from '../src/security/attestation.js';
import { InMemoryRateLimiter } from '../src/security/rateLimit.js';

const audio = validAudio;

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
    expect(res.json().error).toBe('audio_too_large');
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

/**
 * The duration limit is the cap that actually bounds cost: transcription is billed per minute, and
 * `MAX_AUDIO_BYTES` cannot bound minutes. Every case here asserts the decision is made *before* the
 * provider is reached, because a request that reaches the provider has already cost money.
 */
describe('POST /v1/transcriptions duration limit', () => {
  it('accepts a recording just under the limit (299s)', async () => {
    const provider = new FakeTranscriptionProvider();
    const app = await buildTestServer({ provider, config: { MAX_AUDIO_BYTES: 1 << 20 } });
    const res = await app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(m4a(299)) });
    expect(res.statusCode).toBe(200);
    expect(provider.calls).toBe(1);
    await app.close();
  });

  it('accepts a recording exactly at the limit (300s)', async () => {
    const provider = new FakeTranscriptionProvider();
    const app = await buildTestServer({ provider, config: { MAX_AUDIO_BYTES: 1 << 20 } });
    const res = await app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(m4a(300)) });
    expect(res.statusCode).toBe(200);
    expect(provider.calls).toBe(1);
    await app.close();
  });

  it('rejects a recording one second over the limit (301s)', async () => {
    const provider = new FakeTranscriptionProvider();
    const app = await buildTestServer({ provider, config: { MAX_AUDIO_BYTES: 1 << 20 } });
    const res = await app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(m4a(301)) });
    expect(res.statusCode).toBe(413);
    expect(res.json().error).toBe('audio_duration_exceeded');
    expect(provider.calls).toBe(0);
    await app.close();
  });

  it('tells the client what the limit is, so its copy is not hard-coded', async () => {
    const app = await buildTestServer({ config: { MAX_AUDIO_BYTES: 1 << 20, MAX_DURATION_SECONDS: 300 } });
    const res = await app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(m4a(301)) });
    expect(res.statusCode).toBe(413);
    expect(res.json().maxSeconds).toBe(300);
    await app.close();
  });

  it('honours a configured limit other than the default', async () => {
    const app = await buildTestServer({ config: { MAX_AUDIO_BYTES: 1 << 20, MAX_DURATION_SECONDS: 60 } });
    const under = await app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(m4a(59)) });
    const over = await app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(m4a(61)) });
    expect(under.statusCode).toBe(200);
    expect(over.statusCode).toBe(413);
    await app.close();
  });

  it('rejects long low-bitrate audio that sits far under the byte cap', async () => {
    // 11 minutes in well under 4 KB. This is the exact shape the byte cap cannot see: bytes are not
    // minutes, and OpenAI charges for the minutes.
    const provider = new FakeTranscriptionProvider();
    const sneaky = m4a(660, { padBytes: 512 });
    expect(sneaky.byteLength).toBeLessThan(4096);

    const app = await buildTestServer({ provider, config: { MAX_AUDIO_BYTES: 25 * 1024 * 1024 } });
    const res = await app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(sneaky) });
    expect(res.statusCode).toBe(413);
    expect(res.json().error).toBe('audio_duration_exceeded');
    expect(provider.calls).toBe(0);
    await app.close();
  });

  it('applies the limit to every accepted container, not just m4a', async () => {
    const provider = new FakeTranscriptionProvider();
    const app = await buildTestServer({ provider, config: { MAX_AUDIO_BYTES: 25 * 1024 * 1024 } });

    const wavRes = await app.inject({
      method: 'POST',
      url: '/v1/transcriptions',
      ...multipartAudio(wav(700, { sampleRate: 8000 }), { filename: 'note.wav', contentType: 'audio/wav' }),
    });
    const adtsRes = await app.inject({
      method: 'POST',
      url: '/v1/transcriptions',
      ...multipartAudio(adts(700), { filename: 'note.aac', contentType: 'audio/aac' }),
    });
    const mp3Res = await app.inject({
      method: 'POST',
      url: '/v1/transcriptions',
      ...multipartAudio(mp3(700), { filename: 'note.mp3', contentType: 'audio/mpeg' }),
    });

    for (const res of [wavRes, adtsRes, mp3Res]) {
      expect(res.statusCode).toBe(413);
      expect(res.json().error).toBe('audio_duration_exceeded');
    }
    expect(provider.calls).toBe(0);
    await app.close();
  });

  it('fails closed on audio whose duration cannot be read', async () => {
    const provider = new FakeTranscriptionProvider();
    const app = await buildTestServer({ provider });
    const res = await app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(notAudio) });
    expect(res.statusCode).toBe(400);
    expect(res.json().error).toBe('unreadable_audio');
    expect(provider.calls).toBe(0);
    await app.close();
  });

  it('does not let a truthful content type vouch for unmeasurable bytes', async () => {
    // The MIME allowlist is about what we accept; it never substitutes for measuring the container.
    const provider = new FakeTranscriptionProvider();
    const app = await buildTestServer({ provider });
    const res = await app.inject({
      method: 'POST',
      url: '/v1/transcriptions',
      ...multipartAudio(Buffer.alloc(256, 7), { contentType: 'audio/mp4' }),
    });
    expect(res.statusCode).toBe(400);
    expect(res.json().error).toBe('unreadable_audio');
    expect(provider.calls).toBe(0);
    await app.close();
  });

  it('keeps the byte limit working independently of the duration limit', async () => {
    // Short enough to pass the duration check, too big to pass the byte check.
    const provider = new FakeTranscriptionProvider();
    const app = await buildTestServer({ provider, config: { MAX_AUDIO_BYTES: 512 } });
    const res = await app.inject({
      method: 'POST',
      url: '/v1/transcriptions',
      ...multipartAudio(m4a(5, { padBytes: 4096 })),
    });
    expect(res.statusCode).toBe(413);
    expect(res.json().error).toBe('audio_too_large');
    expect(provider.calls).toBe(0);
    await app.close();
  });

  it('logs only safe metadata when it rejects on duration', async () => {
    const logs = captureLogs();
    const app = await buildTestServer({
      config: { MAX_AUDIO_BYTES: 1 << 20 },
      deps: { logDestination: logs.destination },
    });
    await app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(m4a(900)) });
    await app.close();

    const rejection = logs.records().find((r) => r.msg === 'audio duration over limit');
    expect(rejection).toBeDefined();
    expect(rejection!.seconds).toBe(900);
    expect(rejection!.maxSeconds).toBe(300);
    expect(rejection!.status).toBe(413);
    expect(rejection!.bytes).toEqual(expect.any(Number));

    // Nothing derived from the audio may reach a log sink (RULES.md §3). The multipart body carries
    // the literal bytes "ftyp"/"mvhd"/"mdat", so their absence is a direct check that no part of the
    // upload was serialized anywhere in the stream.
    const raw = logs.raw();
    for (const marker of ['ftyp', 'mvhd', 'mdat', 'multipart/form-data']) {
      expect(raw).not.toContain(marker);
    }
  });

  it('logs the measured duration on success, and never the transcript', async () => {
    const logs = captureLogs();
    const app = await buildTestServer({
      config: { MAX_AUDIO_BYTES: 1 << 20 },
      deps: { logDestination: logs.destination },
    });
    await app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(m4a(42)) });
    await app.close();

    const ok = logs.records().find((r) => r.msg === 'transcription ok');
    expect(ok).toBeDefined();
    expect(ok!.seconds).toBe(42);
    expect(ok!.model).toBe('fake-transcribe');
    expect(logs.raw()).not.toContain('Anchorage');
  });
});
