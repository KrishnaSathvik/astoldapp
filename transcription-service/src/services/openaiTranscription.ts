import OpenAI, { toFile } from 'openai';
import { promptFor } from '../prompt.js';
import {
  EmptyTranscriptError,
  type TranscriptionInput,
  type TranscriptionProvider,
  type TranscriptionResult,
} from './transcription.js';

/**
 * Real relay to OpenAI's transcription API using `gpt-4o-transcribe` (docs/06-tech-stack.md §8).
 *
 * Contract enforcement:
 *  - Sends ONLY the audio, the static instruction, and (optionally) language hints — never the note.
 *  - No second text-generation / cleanup pass (RULES.md §2, docs/04-voice-transcription.md §11).
 *    Punctuation comes from the transcription model itself, never from a rewrite pass.
 *  - Does not force a single language, because code-switching is a core use case.
 */
export class OpenAITranscriptionProvider implements TranscriptionProvider {
  private readonly client: OpenAI;

  private readonly prompt: string;

  constructor(
    apiKey: string,
    readonly model: string = 'gpt-4o-transcribe',
    promptVariant?: string,
  ) {
    this.client = new OpenAI({ apiKey });
    this.prompt = promptFor(promptVariant);
  }

  async transcribe(input: TranscriptionInput): Promise<TranscriptionResult> {
    const file = await toFile(input.audio, input.filename, { type: input.contentType });

    const response = await this.client.audio.transcriptions.create({
      file,
      model: this.model,
      prompt: this.prompt,
      // `language` intentionally omitted: forcing one language would collapse code-switching.
      // Evaluate expected-language hints per docs/04-voice-transcription.md §10 (benchmark-driven).
      response_format: 'json',
    });

    const text = (response.text ?? '').trim();
    if (text.length === 0) throw new EmptyTranscriptError();

    // `gpt-4o-transcribe` json does not return per-language detection; kept empty rather than guessed.
    return { text, languages: [] };
  }
}
