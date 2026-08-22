import { describe, it, expect } from 'vitest';
import { buildTestServer, captureLogs, multipartAudio } from './helpers.js';
import { m4a } from './fixtures.js';
import { FakeTranscriptionProvider } from '../src/services/fakeTranscription.js';
import { EmptyTranscriptError } from '../src/services/transcription.js';
import { MemoryVoiceUsageStore } from '../src/security/voiceUsage.js';

const CEILING = 3600;
const BIG = { MAX_AUDIO_BYTES: 1 << 20 }; // minutes of audio do not fit the default tiny cap

/** DevBypassVerifier's identity when no attestation header is sent. */
const INSTALL = 'dev-install';

/** A store already carrying `seconds` of usage for this month, as if the user had been speaking. */
function usageAt(seconds: number): MemoryVoiceUsageStore {
  const usage = new MemoryVoiceUsageStore(CEILING);
  if (seconds > 0) usage.reserve(INSTALL, seconds);
  return usage;
}

function post(app: Awaited<ReturnType<typeof buildTestServer>>, seconds: number) {
  return app.inject({ method: 'POST', url: '/v1/transcriptions', ...multipartAudio(m4a(seconds)) });
}

/**
 * The monthly fair-use ceiling at the route level (docs/04-voice-transcription.md §14). The store's
 * own arithmetic is covered in voiceUsage.test.ts; what matters here is *where* the ceiling sits in
 * the request flow — after every free rejection, before the paid call, refunded on every exit that
 * does not return a transcript.
 */
describe('POST /v1/transcriptions monthly allowance', () => {
  it('transcribes normally for an installation that has used nothing', async () => {
    const provider = new FakeTranscriptionProvider();
    const app = await buildTestServer({ provider, config: BIG, deps: { usage: usageAt(0) } });

    const res = await post(app, 60);

    expect(res.statusCode).toBe(200);
    expect(provider.calls).toBe(1);
    await app.close();
  });

  it('lets a recording started under the ceiling finish, then refuses the next', async () => {
    const provider = new FakeTranscriptionProvider();
    const usage = usageAt(3540); // 59 minutes
    const app = await buildTestServer({ provider, config: BIG, deps: { usage } });

    const crossing = await post(app, 60); // lands exactly on 60 minutes
    expect(crossing.statusCode).toBe(200);

    const next = await post(app, 10);
    expect(next.statusCode).toBe(429);
    expect(next.json().error).toBe('monthly_voice_limit');
    expect(provider.calls).toBe(1); // the refused one never reached the provider
    await app.close();
  });

  it('allows a full 5-minute recording from 59 minutes rather than truncating it', async () => {
    const provider = new FakeTranscriptionProvider();
    const app = await buildTestServer({ provider, config: BIG, deps: { usage: usageAt(3540) } });

    // The whole point of a soft ceiling: nobody speaks for five minutes and is then told only
    // sixty seconds remained.
    const res = await post(app, 300);

    expect(res.statusCode).toBe(200);
    expect(res.json().text).toBeTruthy();
    expect(provider.calls).toBe(1);
    await app.close();
  });

  it('tells the crossing recording that it spent the last of the allowance', async () => {
    // The whole point: the successful response carries the news, so the *next* tap can be stopped
    // locally and no spoken thought is sacrificed to discover the ceiling.
    const app = await buildTestServer({ config: BIG, deps: { usage: usageAt(3540) } });

    const res = await post(app, 300); // 59m + 5m — allowed whole, and that was the last of it
    const body = res.json();

    expect(res.statusCode).toBe(200);
    expect(body.text).toBeTruthy();
    expect(body.allowanceExhausted).toBe(true);
    expect(body.resetsAt).toMatch(/^\d{4}-\d{2}-01T00:00:00\.000Z$/);
    await app.close();
  });

  it('says nothing about the allowance while there is room left', async () => {
    const app = await buildTestServer({ config: BIG, deps: { usage: usageAt(0) } });

    const body = (await post(app, 60)).json();

    expect(body.text).toBeTruthy();
    expect(body.allowanceExhausted).toBeUndefined();
    expect(body.resetsAt).toBeUndefined();
    await app.close();
  });

  /// No usage meter ships, so the relay never hands the app the numbers one would need
  /// (RULES.md §1). A successful response carries a transcript, a flag, and a date — nothing else.
  it('never returns usage figures the app could draw a meter with', async () => {
    const exhausting = await buildTestServer({ config: BIG, deps: { usage: usageAt(3540) } });
    const crossed = (await post(exhausting, 300)).json();
    await exhausting.close();

    const roomy = await buildTestServer({ config: BIG, deps: { usage: usageAt(600) } });
    const normal = (await post(roomy, 60)).json();
    await roomy.close();

    const refused = await buildTestServer({ config: BIG, deps: { usage: usageAt(CEILING) } });
    const denied = (await post(refused, 10)).json();
    await refused.close();

    for (const body of [crossed, normal, denied]) {
      for (const key of ['usedSeconds', 'remainingSeconds', 'used', 'remaining', 'limit',
                         'ceiling', 'quota', 'minutes', 'allowanceSeconds']) {
        expect(body[key]).toBeUndefined();
      }
    }
    expect(Object.keys(crossed).sort()).toEqual([
      'allowanceExhausted', 'languages', 'requestId', 'resetsAt', 'text',
    ]);
  });

  /// The server-side fallback still has to work: a reinstalled or stale client that never saw the
  /// exhaustion flag will upload anyway, and it must be refused rather than transcribed.
  it('still refuses a client that uploads after exhaustion regardless', async () => {
    const provider = new FakeTranscriptionProvider();
    const usage = usageAt(3540);
    const app = await buildTestServer({ provider, config: BIG, deps: { usage } });

    expect((await post(app, 300)).json().allowanceExhausted).toBe(true);

    // A client that ignored the flag entirely — exactly what a stale build or a replayed request
    // looks like from here.
    const late = await post(app, 60);
    expect(late.statusCode).toBe(429);
    expect(late.json().error).toBe('monthly_voice_limit');
    expect(late.json().resetsAt).toBeDefined();
    expect(provider.calls).toBe(1); // the second one never reached the provider
    await app.close();
  });

  it('does not report exhaustion when the crossing recording was refunded', async () => {
    // The reservation is released, so the allowance is not spent and nothing should claim it was.
    const provider = new FakeTranscriptionProvider(undefined, new EmptyTranscriptError());
    const usage = usageAt(3540);
    const app = await buildTestServer({ provider, config: BIG, deps: { usage } });

    const silent = await post(app, 300);
    expect(silent.statusCode).toBe(422);
    expect(silent.json().allowanceExhausted).toBeUndefined(); // nothing was spent, nothing to report
    await app.close();

    // Usage is back to 59m, so a short recording is admitted and still leaves room — which it would
    // not if the refunded five minutes had stuck.
    const next = await buildTestServer({ config: BIG, deps: { usage } });
    const body = (await post(next, 30)).json();
    expect(body.text).toBeTruthy();
    expect(body.allowanceExhausted).toBeUndefined();
    await next.close();
  });

  it('refuses at the ceiling before spending money', async () => {
    const provider = new FakeTranscriptionProvider();
    const app = await buildTestServer({ provider, config: BIG, deps: { usage: usageAt(CEILING) } });

    const res = await post(app, 10);

    expect(res.statusCode).toBe(429);
    expect(res.json().error).toBe('monthly_voice_limit');
    expect(provider.calls).toBe(0);
    await app.close();
  });

  it('returns an authoritative resetsAt at the start of the next UTC month', async () => {
    const app = await buildTestServer({ config: BIG, deps: { usage: usageAt(CEILING) } });

    const body = (await post(app, 10)).json();

    expect(body.resetsAt).toMatch(/^\d{4}-\d{2}-01T00:00:00\.000Z$/);
    const reset = new Date(body.resetsAt);
    expect(reset.getTime()).toBeGreaterThan(Date.now()); // in the future, so the copy reads sensibly
    expect(reset.getUTCDate()).toBe(1);
    await app.close();
  });

  it('keeps the monthly refusal distinguishable from the rate limiter', async () => {
    // Both are 429; only the code separates them, and they get different copy in the app.
    const overLimit = await buildTestServer({ config: BIG, deps: { usage: usageAt(CEILING) } });
    const monthly = (await post(overLimit, 10)).json();
    await overLimit.close();

    const app = await buildTestServer({ config: { ...BIG, RATE_LIMIT_MAX: 1 } });
    await post(app, 10);
    const rateLimited = (await post(app, 10)).json();
    await app.close();

    expect(monthly.error).toBe('monthly_voice_limit');
    expect(monthly.resetsAt).toBeDefined();
    expect(rateLimited.error).toBe('rate_limited');
    expect(rateLimited.resetsAt).toBeUndefined();
  });

  it('keeps the reservation when a transcript comes back', async () => {
    const usage = usageAt(3540);
    const app = await buildTestServer({ config: BIG, deps: { usage } });

    expect((await post(app, 60)).statusCode).toBe(200); // reaches exactly 60 minutes
    expect((await post(app, 10)).statusCode).toBe(429); // so the allowance is spent

    await app.close();
  });

  it('refunds when the provider fails', async () => {
    const provider = new FakeTranscriptionProvider(undefined, new Error('upstream exploded'));
    const usage = usageAt(3540);
    const logs = captureLogs();
    const app = await buildTestServer({
      provider,
      config: BIG,
      deps: { usage, logDestination: logs.destination },
    });

    const failed = await post(app, 60);
    expect(failed.statusCode).toBe(502);
    await app.close();

    // Had the 60s stuck, usage would be at the ceiling and this would be refused.
    const next = await buildTestServer({ config: BIG, deps: { usage } });
    expect((await post(next, 60)).statusCode).toBe(200);
    await next.close();
  });

  it('refunds when the provider returns no speech', async () => {
    const provider = new FakeTranscriptionProvider(undefined, new EmptyTranscriptError());
    const usage = usageAt(3540);
    const app = await buildTestServer({ provider, config: BIG, deps: { usage } });

    const silent = await post(app, 60);
    expect(silent.statusCode).toBe(422);
    expect(silent.json().error).toBe('no_speech');
    await app.close();

    // As Told paid for that call; the user is not charged for words they never got back.
    const next = await buildTestServer({ config: BIG, deps: { usage } });
    expect((await post(next, 60)).statusCode).toBe(200);
    await next.close();
  });

  it('never reserves for a request rejected before the paid call', async () => {
    const usage = usageAt(3540);

    const tooLong = await buildTestServer({ config: BIG, deps: { usage } });
    expect((await post(tooLong, 301)).statusCode).toBe(413); // over the 5-minute cap
    await tooLong.close();

    const badMime = await buildTestServer({ config: BIG, deps: { usage } });
    const res = await badMime.inject({
      method: 'POST',
      url: '/v1/transcriptions',
      ...multipartAudio(m4a(60), { contentType: 'audio/ogg' }),
    });
    expect(res.statusCode).toBe(415);
    await badMime.close();

    // Neither rejection touched the counter, so a full minute is still available.
    const app = await buildTestServer({ config: BIG, deps: { usage } });
    expect((await post(app, 60)).statusCode).toBe(200);
    await app.close();
  });

  it('admits only one of two concurrent requests at the ceiling', async () => {
    const provider = new FakeTranscriptionProvider();
    // One second below the ceiling: without an atomic reserve, both requests read "under" and both
    // reach the provider.
    const app = await buildTestServer({
      provider,
      config: BIG,
      deps: { usage: usageAt(CEILING - 1) },
    });

    const [a, b] = await Promise.all([post(app, 60), post(app, 60)]);
    const statuses = [a.statusCode, b.statusCode].sort();

    expect(statuses).toEqual([200, 429]);
    expect(provider.calls).toBe(1);
    await app.close();
  });

  it('logs the refusal as metadata only', async () => {
    const logs = captureLogs();
    const app = await buildTestServer({
      config: BIG,
      deps: { usage: usageAt(CEILING), logDestination: logs.destination },
    });

    await post(app, 10);
    await app.close();

    const record = logs.records().find((r) => r.msg === 'monthly voice allowance reached');
    expect(record).toBeDefined();
    expect(record!.status).toBe(429);
    // No transcript, no audio, and not even the install id — the hash stays inside the store.
    expect(logs.raw()).not.toContain(INSTALL);
  });

  it('accounts the same way whatever language came back', async () => {
    // The allowance is duration, not content: a Telugu minute and an English minute cost the same.
    for (const languages of [['en'], ['te'], ['te', 'en'], ['hi', 'en']]) {
      const provider = new FakeTranscriptionProvider({ text: 'transcribed', languages });
      const usage = usageAt(3540);
      const app = await buildTestServer({ provider, config: BIG, deps: { usage } });

      expect((await post(app, 60)).statusCode).toBe(200);
      expect((await post(app, 10)).statusCode).toBe(429); // same 60s charged every time
      await app.close();
    }
  });
});
