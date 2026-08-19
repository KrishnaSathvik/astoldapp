import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { ALLOWED_AUDIO_MIME, type Config } from '../config.js';
import { audioDurationSeconds, UnreadableAudioError } from '../media/audioDuration.js';
import { AttestationError, type AttestationVerifier } from '../security/attestation.js';
import type { RateLimiter } from '../security/rateLimit.js';
import {
  EmptyTranscriptError,
  type TranscriptionProvider,
} from '../services/transcription.js';

interface TranscribeDeps {
  config: Config;
  provider: TranscriptionProvider;
  verifier: AttestationVerifier;
  limiter: RateLimiter;
}

export async function transcribeRoutes(
  app: FastifyInstance,
  deps: TranscribeDeps,
): Promise<void> {
  const { config, provider, verifier, limiter } = deps;

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

    // 7) Relay to the provider. Nothing is persisted; the buffer is dropped after this scope.
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
      });
    } catch (err) {
      if (err instanceof EmptyTranscriptError) {
        return reply.code(422).send({ requestId, error: 'no_speech' });
      }
      req.log.error({ requestId, status: 502, err_kind: (err as Error).name }, 'transcription failed');
      return reply.code(502).send({ requestId, error: 'transcription_failed' });
    }
  });
}
