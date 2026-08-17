/** Input audio to transcribe. Held only in memory for the duration of the request. */
export interface TranscriptionInput {
  audio: Buffer;
  filename: string;
  contentType: string;
  requestId: string;
}

/** Transcript plus detected languages (metadata, never persisted). */
export interface TranscriptionResult {
  text: string;
  languages: string[];
}

/** Relays a completed recording to a transcription backend. Implementations must not persist content. */
export interface TranscriptionProvider {
  readonly model: string;
  transcribe(input: TranscriptionInput): Promise<TranscriptionResult>;
}

/** Thrown when the provider returns nothing usable — treated as a failure, never guessed text. */
export class EmptyTranscriptError extends Error {
  constructor() {
    super('empty transcript');
    this.name = 'EmptyTranscriptError';
  }
}
