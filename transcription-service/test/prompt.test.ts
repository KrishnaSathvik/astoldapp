import { describe, expect, it } from 'vitest';
import {
  DEFAULT_PROMPT_VARIANT,
  PROMPT_VARIANTS,
  VERBATIM_PROMPT,
  promptFor,
} from '../src/prompt.js';

/**
 * The prompt is the product contract in one string (RULES.md §2). These lock the two halves of
 * "Preserve the words. Format the speech." so neither can drift out of the shipping instruction.
 */
describe('transcription instruction', () => {
  it('ships the punctuated variant by default', () => {
    expect(promptFor(undefined)).toBe(VERBATIM_PROMPT);
    expect(PROMPT_VARIANTS[DEFAULT_PROMPT_VARIANT]).toBe(VERBATIM_PROMPT);
  });

  it('falls back to the default for an unknown variant name', () => {
    expect(promptFor('does-not-exist')).toBe(VERBATIM_PROMPT);
    expect(promptFor('')).toBe(VERBATIM_PROMPT);
  });

  it('selects a named benchmark arm', () => {
    expect(promptFor('strictVerbatim')).toBe(PROMPT_VARIANTS.strictVerbatim);
    expect(promptFor('terse')).toBe(PROMPT_VARIANTS.terse);
  });

  it('allows readability formatting in the shipping prompt', () => {
    expect(VERBATIM_PROMPT).toMatch(/punctuation/i);
    expect(VERBATIM_PROMPT).toMatch(/capitalization/i);
    expect(VERBATIM_PROMPT).toMatch(/paragraph breaks/i);
  });

  it('forbids changing the speaker’s words in every variant', () => {
    for (const [name, prompt] of Object.entries(PROMPT_VARIANTS)) {
      expect(prompt, name).toMatch(/do not translate/i);
      expect(prompt, name).toMatch(/rewrite/i);
      expect(prompt, name).toMatch(/grammar/i);
    }
  });

  it('never instructs the model to translate, summarize or improve', () => {
    for (const [name, prompt] of Object.entries(PROMPT_VARIANTS)) {
      // Every occurrence of these verbs must be inside a negation.
      for (const verb of ['translate', 'summarize', 'rewrite', 'paraphrase']) {
        const matches = [...prompt.matchAll(new RegExp(verb, 'gi'))];
        for (const match of matches) {
          const preceding = prompt.slice(0, match.index ?? 0);
          expect(preceding, `${name}: "${verb}" must follow "Do not"`).toMatch(/do not[^.]*$/i);
        }
      }
    }
  });
});
