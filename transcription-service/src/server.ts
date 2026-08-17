import Fastify, { type FastifyInstance } from 'fastify';
import multipart from '@fastify/multipart';
import type { Config } from './config.js';
import { loggerOptions } from './observability/logger.js';
import { healthRoutes } from './routes/health.js';
import { appAttestRoutes } from './routes/appAttest.js';
import { transcribeRoutes } from './routes/transcribe.js';
import { makeVerifier, type AttestationVerifier } from './security/attestation.js';
import { InMemoryRateLimiter, type RateLimiter } from './security/rateLimit.js';
import { FakeTranscriptionProvider } from './services/fakeTranscription.js';
import { OpenAITranscriptionProvider } from './services/openaiTranscription.js';
import type { TranscriptionProvider } from './services/transcription.js';

export interface Deps {
  config: Config;
  provider: TranscriptionProvider;
  verifier: AttestationVerifier;
  limiter: RateLimiter;
}

/** Wire default dependencies from config: real provider only when a key is present. */
export function makeDefaultDeps(config: Config): Deps {
  const provider: TranscriptionProvider = config.OPENAI_API_KEY
    ? new OpenAITranscriptionProvider(config.OPENAI_API_KEY, config.TRANSCRIBE_MODEL)
    : new FakeTranscriptionProvider();

  return {
    config,
    provider,
    verifier: makeVerifier(config.APP_ATTEST_REQUIRED),
    limiter: new InMemoryRateLimiter(
      config.RATE_LIMIT_MAX,
      config.RATE_LIMIT_WINDOW_SECONDS * 1000,
    ),
  };
}

export async function buildServer(deps: Deps): Promise<FastifyInstance> {
  const app = Fastify({
    logger: loggerOptions(deps.config.NODE_ENV),
    bodyLimit: deps.config.MAX_AUDIO_BYTES + 1_048_576, // audio + small multipart overhead
  });

  await app.register(multipart, {
    limits: { fileSize: deps.config.MAX_AUDIO_BYTES, files: 1, fields: 4 },
  });

  await app.register(healthRoutes);
  await app.register(async (scoped) => appAttestRoutes(scoped, deps.verifier));
  await app.register(async (scoped) => transcribeRoutes(scoped, deps));

  return app;
}
