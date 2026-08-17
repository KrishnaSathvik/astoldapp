/**
 * Static, verbatim transcription instruction. This is the product's core contract (RULES.md §2,
 * docs/04-voice-transcription.md §9). It must NOT be turned into a rewrite/translation instruction,
 * and it must NOT be made remotely mutable in unsafe ways.
 *
 * The user's note content is never sent as context — only the audio, this static instruction, and
 * allowed language hints (docs/04-voice-transcription.md §9 "Critical privacy rule").
 */
export const VERBATIM_PROMPT = [
  'Transcribe the recording faithfully in the original language(s).',
  'Preserve English, Telugu, and Hindi code-switching exactly as spoken.',
  'Do not translate, summarize, rewrite, or improve grammar.',
  'Prefer the native writing system for Telugu and Hindi when spoken.',
  'Preserve natural repeated words, slang, names, and filler words where audible.',
].join(' ');

/** Expected-language hints evaluated for supported codes (benchmark-driven, not forced). */
export const LANGUAGE_HINTS = ['en', 'te', 'hi'] as const;
