/**
 * Transcription instructions. This is the product's core contract (RULES.md §2,
 * docs/04-voice-transcription.md §9):
 *
 *   **Preserve the words. Format the speech.**
 *
 * Readability formatting (capitalization, punctuation, sentence and paragraph boundaries) is
 * allowed because it is how written language represents speech. Changing *which words the speaker
 * used* — grammar correction, vocabulary swaps, paraphrase, summary, translation, tone — is not,
 * and never becomes allowed. These must NOT be turned into rewrite/translation instructions, and
 * must NOT be made remotely mutable in unsafe ways.
 *
 * The user's note content is never sent as context — only the audio, one of these static
 * instructions, and allowed language hints (docs/04-voice-transcription.md §9 "Critical privacy rule").
 */

/** The shipping instruction. `PROMPT_VARIANTS.punctuated` is the same string, benchmarked by name. */
export const VERBATIM_PROMPT = [
  'Transcribe the recording faithfully in the original language(s).',
  'Preserve English, Telugu, and Hindi code-switching exactly as spoken.',
  'Preserve the speaker’s actual words, slang, repetitions, and names.',
  'Add natural capitalization, punctuation, sentence boundaries, and paragraph breaks where the speech supports them.',
  'Do not translate, summarize, rewrite, paraphrase, or correct grammar.',
  'Prefer the native writing system for Telugu and Hindi when spoken.',
].join(' ');

/**
 * Prompt variants for the benchmark (docs/benchmark/README.md). The choice between them is made
 * from measured product performance on the corpus — never from which one reads best here.
 * Select at runtime with `TRANSCRIBE_PROMPT_VARIANT`; unknown names fall back to `punctuated`.
 */
export const PROMPT_VARIANTS = {
  /** Shipping default: verbatim wording, natural written punctuation. */
  punctuated: VERBATIM_PROMPT,

  /** Pre-2026-08-18 behaviour, kept as the benchmark control arm. */
  strictVerbatim: [
    'Transcribe the recording faithfully in the original language(s).',
    'Preserve English, Telugu, and Hindi code-switching exactly as spoken.',
    'Do not translate, summarize, rewrite, or improve grammar.',
    'Prefer the native writing system for Telugu and Hindi when spoken.',
    'Preserve natural repeated words, slang, names, and filler words where audible.',
  ].join(' '),

  /** Shorter instruction — tests whether a long prompt is itself costing accuracy. */
  terse: [
    'Transcribe faithfully in the original language(s), preserving code-switching, slang, and names.',
    'Use natural punctuation and capitalization. Do not translate, rewrite, or fix grammar.',
  ].join(' '),
} as const;

export type PromptVariant = keyof typeof PROMPT_VARIANTS;

export const DEFAULT_PROMPT_VARIANT: PromptVariant = 'punctuated';

export function promptFor(variant: string | undefined): string {
  if (variant && variant in PROMPT_VARIANTS) {
    return PROMPT_VARIANTS[variant as PromptVariant];
  }
  return PROMPT_VARIANTS[DEFAULT_PROMPT_VARIANT];
}

/** Expected-language hints evaluated for supported codes (benchmark-driven, not forced). */
export const LANGUAGE_HINTS = ['en', 'te', 'hi'] as const;
