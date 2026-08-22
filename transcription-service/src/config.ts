import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(8787),
  OPENAI_API_KEY: z.string().optional(),
  // Kept at gpt-4o-transcribe until a benchmark run on the real corpus says otherwise — never
  // changed because another model is newer or generically recommended (docs/benchmark/README.md).
  TRANSCRIBE_MODEL: z.string().default('gpt-4o-transcribe'),
  // Benchmark arm selector for the transcription instruction; see src/prompt.ts.
  TRANSCRIBE_PROMPT_VARIANT: z.string().default('punctuated'),
  MAX_AUDIO_BYTES: z.coerce.number().int().positive().default(26_214_400),
  MAX_DURATION_SECONDS: z.coerce.number().int().positive().default(300),
  RATE_LIMIT_MAX: z.coerce.number().int().positive().default(20),
  RATE_LIMIT_WINDOW_SECONDS: z.coerce.number().int().positive().default(60),
  // Monthly fair-use allowance per attested install, in seconds (60 minutes). A *soft* ceiling and a
  // different control from the two above: the rate limit stops bursts, MAX_DURATION_SECONDS stops one
  // runaway request, and this stops sustained spend over a month. Do not trade one against another
  // (RULES.md §3, docs/04-voice-transcription.md §14).
  MONTHLY_VOICE_SECONDS: z.coerce.number().int().positive().default(3600),
  APP_ATTEST_REQUIRED: z
    .enum(['true', 'false'])
    .default('false')
    .transform((v) => v === 'true'),
  // "TEAMID.bundleId", e.g. "ABCDE12345.com.astold.app" — required when App Attest is enabled.
  APP_ATTEST_APP_ID: z.string().optional(),
  // Require the production AAGUID ("appattest"); dev builds use "appattestdevelop".
  APP_ATTEST_PRODUCTION: z
    .enum(['true', 'false'])
    .default('false')
    .transform((v) => v === 'true'),
  // File backing the attested-key registry. Must sit on a mounted volume: the assertion counter
  // only defends against replay if it survives restarts and deploys (RULES.md §3).
  APP_ATTEST_DB_PATH: z.string().optional(),
  // Deliberate, visible opt-out for a production relay that is knowingly left unprotected
  // (the pre-launch staging deploy). Never set this on a build real users can reach.
  APP_ATTEST_ALLOW_UNPROTECTED: z
    .enum(['true', 'false'])
    .default('false')
    .transform((v) => v === 'true'),
});

export type Config = z.infer<typeof schema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = schema.parse(env);

  // Safety rail: a production relay must not run without attestation. Transcription costs real
  // money per request, so an open endpoint is a standing bill for anyone who finds the URL. The
  // opt-out exists for the pre-launch staging deploy and has to be typed out on purpose.
  if (
    parsed.NODE_ENV === 'production' &&
    !parsed.APP_ATTEST_REQUIRED &&
    !parsed.APP_ATTEST_ALLOW_UNPROTECTED
  ) {
    throw new Error(
      'APP_ATTEST_REQUIRED=false in production leaves the transcription endpoint open. ' +
        'Set APP_ATTEST_REQUIRED=true, or APP_ATTEST_ALLOW_UNPROTECTED=true to accept the risk.',
    );
  }

  // Enforcing attestation with a process-local registry would drop every key on restart, which both
  // breaks replay defence and re-registers every install. Make the durable path explicit.
  if (parsed.APP_ATTEST_REQUIRED && !parsed.APP_ATTEST_DB_PATH) {
    throw new Error(
      'APP_ATTEST_DB_PATH is required when APP_ATTEST_REQUIRED=true — point it at a mounted volume ' +
        'so attested keys and assertion counters survive restarts.',
    );
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
