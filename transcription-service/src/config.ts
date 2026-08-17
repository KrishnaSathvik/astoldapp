import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(8787),
  OPENAI_API_KEY: z.string().optional(),
  TRANSCRIBE_MODEL: z.string().default('gpt-4o-transcribe'),
  MAX_AUDIO_BYTES: z.coerce.number().int().positive().default(26_214_400),
  MAX_DURATION_SECONDS: z.coerce.number().int().positive().default(600),
  RATE_LIMIT_MAX: z.coerce.number().int().positive().default(20),
  RATE_LIMIT_WINDOW_SECONDS: z.coerce.number().int().positive().default(60),
  APP_ATTEST_REQUIRED: z
    .enum(['true', 'false'])
    .default('false')
    .transform((v) => v === 'true'),
});

export type Config = z.infer<typeof schema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = schema.parse(env);
  // Safety rail: production must not silently run without attestation.
  if (parsed.NODE_ENV === 'production' && !parsed.APP_ATTEST_REQUIRED) {
    // eslint-disable-next-line no-console
    console.warn('[config] WARNING: APP_ATTEST_REQUIRED=false in production — the endpoint is unprotected.');
  }
  return parsed;
}

/** Allowed uploaded audio content types (docs/04-voice-transcription.md §7). */
export const ALLOWED_AUDIO_MIME = new Set([
  'audio/m4a',
  'audio/x-m4a',
  'audio/mp4',
  'audio/aac',
  'audio/mpeg',
  'audio/wav',
]);
