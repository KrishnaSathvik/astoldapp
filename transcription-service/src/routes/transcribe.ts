import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { ALLOWED_AUDIO_MIME, type Config } from '../config.js';
import { audioDurationSeconds, UnreadableAudioError } from '../media/audioDuration.js';
import { AttestationError, type AttestationVerifier } from '../security/attestation.js';
import type { RateLimiter } from '../security/rateLimit.js';
import type { VoiceUsageStore } from '../security/voiceUsage.js';
import {
  EmptyTranscriptError,
  type TranscriptionProvider,
} from '../services/transcription.js';

interface TranscribeDeps {
  config: Config;
  provider: TranscriptionProvider;
  verifier: AttestationVerifier;
  limiter: RateLimiter;
  usage: VoiceUsageStore;
}

export async function transcribeRoutes(
  app: FastifyInstance,
  deps: TranscribeDeps,
): Promise<void> {
  const { config, provider, verifier, limiter, usage } = deps;

  app.post('/v1/transcriptions', async (req, reply) => {
    const requestId =
      (req.headers['x-request-id'] as string | undefined)?.slice(0, 64) ?? randomUUID();

    // 1) Attestation (anti-abuse). Identity is used for rate limiting.
    let identity: string;
    try {
      const result = await verifier.verifyRequest({
        keyId: req.headers['x-attest-key-id'] as string | undefined,
        assertionBase64: req.headers['x-attest-assertion'] as string | undefined,
        challenge: req.headers['x-attest-challenge'] as string | undefined,
      });
      identity = result.identity;
    } catch (err) {
      if (err instanceof AttestationError) {
        return reply.code(401).send({ requestId, error: 'attestation_failed' });
      }
      throw err;
    }

    // 2) Rate limit (primary key = attested identity; IP as secondary).
    const rateKey = `${identity}|${req.ip}`;
    if (!limiter.take(rateKey)) {
      return reply.code(429).send({ requestId, error: 'rate_limited' });
    }

    // 3) Multipart audio.
    const file = await req.file();
    if (!file) {
      return reply.code(400).send({ requestId, error: 'missing_audio' });
    }

    // 4) MIME validation.
    if (!ALLOWED_AUDIO_MIME.has(file.mimetype)) {
      return reply.code(415).send({ requestId, error: 'unsupported_media_type' });
    }

    // 5) Read with size guard.
    let audio: Buffer;
    try {
      audio = await file.toBuffer();
    } catch {
      return reply.code(413).send({ requestId, error: 'audio_too_large' });
    }
    if (file.file.truncated || audio.byteLength > config.MAX_AUDIO_BYTES) {
      return reply.code(413).send({ requestId, error: 'audio_too_large' });
    }
    if (audio.byteLength === 0) {
      return reply.code(400).send({ requestId, error: 'empty_audio' });
    }

    // 6) Duration limit — the authoritative one. The byte cap above does NOT bound minutes (25 MB of
    //    8 kbps AAC is hours of audio), and OpenAI bills per minute, so this is what actually caps
    //    the cost of a single request. Measured from the container here, never taken from the client,
    //    and always checked BEFORE the paid call is made.
    let durationSeconds: number;
    try {
      durationSeconds = audioDurationSeconds(audio);
    } catch (err) {
      if (err instanceof UnreadableAudioError) {
        // Fail closed: audio we cannot measure is audio we cannot bound.
        req.log.warn(
          { requestId, status: 400, bytes: audio.byteLength, reason: err.reason },
          'audio duration unreadable',
        );
        return reply.code(400).send({ requestId, error: 'unreadable_audio' });
      }
      throw err;
    }
    if (durationSeconds > config.MAX_DURATION_SECONDS) {
      req.log.warn(
        {
          requestId,
          status: 413,
          bytes: audio.byteLength,
          seconds: Math.round(durationSeconds),
          maxSeconds: config.MAX_DURATION_SECONDS,
        },
        'audio duration over limit',
      );
      return reply.code(413).send({
        requestId,
        error: 'audio_duration_exceeded',
        maxSeconds: config.MAX_DURATION_SECONDS,
      });
    }

    // 7) Monthly fair-use allowance. The last gate before money is spent, and deliberately after
    //    every free rejection above so a refused request never touches the counter. It charges the
    //    duration measured in step 6 — there is no second measurement and never a client-reported
    //    one. Soft ceiling: being *under* the limit admits this recording whole, however long it is
    //    (docs/04-voice-transcription.md §14).
    const reservation = usage.reserve(identity, durationSeconds);
    if (!reservation.allowed) {
      req.log.info(
        { requestId, status: 429, reason: 'monthly_voice_limit' },
        'monthly voice allowance reached',
      );
      // Shares 429 with the rate limiter, so the code is what separates them: the two mean
      // different things to the user and get different copy.
      return reply.code(429).send({
        requestId,
        error: 'monthly_voice_limit',
        resetsAt: reservation.resetsAt,
      });
    }

    // 8) Relay to the provider. Nothing is persisted; the buffer is dropped after this scope.
    //    Every exit that does not return a transcript refunds — a user is charged for words they
    //    got back, never for a call that happened to cost us money.
    try {
      const result = await provider.transcribe({
        audio,
        filename: file.filename || 'audio.m4a',
        contentType: file.mimetype,
        requestId,
      });
      req.log.info(
        {
          requestId,
          model: provider.model,
          bytes: audio.byteLength,
          seconds: Math.round(durationSeconds),
          status: 200,
        },
        'transcription ok',
      );
      return reply.code(200).send({
        requestId,
        text: result.text,
        languages: result.languages,
        // Only when this very recording spent the last of the allowance. The app caches the reset
        // instant and refuses the *next* microphone tap before the recorder opens, so nobody has to
        // lose a spoken thought to find out where the ceiling was. Deliberately a flag and a date
        // and nothing else — a remaining-minutes figure is a usage meter waiting to be drawn.
        ...(reservation.exhausted
          ? { allowanceExhausted: true, resetsAt: reservation.resetsAt }
          : {}),
      });
    } catch (err) {
      usage.refund(identity, reservation.period, durationSeconds);
      if (err instanceof EmptyTranscriptError) {
        // A billed provider call that returned nothing. We absorb the cost; charging a user for
        // silence they got no text from would be indefensible, and repeated-silence abuse is the
        // rate limiter's problem. Provider cost and user quota are different ledgers.
        return reply.code(422).send({ requestId, error: 'no_speech' });
      }
      req.log.error({ requestId, status: 502, err_kind: (err as Error).name }, 'transcription failed');
      return reply.code(502).send({ requestId, error: 'transcription_failed' });
    }
  });
}
