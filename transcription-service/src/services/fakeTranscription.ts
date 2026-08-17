import type {
  TranscriptionInput,
  TranscriptionProvider,
  TranscriptionResult,
} from './transcription.js';

/**
 * Deterministic provider used when OPENAI_API_KEY is unset (local dev, CI, tests). No network.
 * Mirrors the client's fake sample so the whole relay can be exercised end-to-end without a key.
 */
export class FakeTranscriptionProvider implements TranscriptionProvider {
  readonly model = 'fake-transcribe';

  constructor(
    private readonly override?: TranscriptionResult,
    private readonly failWith?: Error,
  ) {}

  async transcribe(_input: TranscriptionInput): Promise<TranscriptionResult> {
    if (this.failWith) throw this.failWith;
    return (
      this.override ?? {
        text:
          'I was thinking maybe మనం Anchorage లో stay చేయుండా two nights Seward లో stay చేసు better ఉంటుంది.',
        languages: ['te', 'en'],
      }
    );
  }
}
