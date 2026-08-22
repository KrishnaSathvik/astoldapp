import { describe, it, expect } from 'vitest';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Buffer } from 'node:buffer';
import {
  audioDurationSeconds,
  sniffContainer,
  UnreadableAudioError,
} from '../src/media/audioDuration.js';
import { adts, m4a, m4aUnknownDuration, mp3, notAudio, wav } from './fixtures.js';

describe('sniffContainer', () => {
  it('identifies each supported container from its magic bytes', () => {
    expect(sniffContainer(m4a(1))).toBe('mp4');
    expect(sniffContainer(wav(1))).toBe('wav');
    expect(sniffContainer(adts(1))).toBe('adts');
    expect(sniffContainer(mp3(1))).toBe('mpeg');
  });

  it('tells MPEG audio and ADTS apart by the layer field they share a sync word with', () => {
    // 0xFFFB… — MPEG-1 Layer III. 0xFFF1… — ADTS (layer bits 00, reserved in MPEG audio).
    const mp3ish = Buffer.concat([Buffer.from([0xff, 0xfb, 0x90, 0x00]), Buffer.alloc(16)]);
    const adtsish = Buffer.concat([Buffer.from([0xff, 0xf1, 0x50, 0x80]), Buffer.alloc(16)]);
    expect(sniffContainer(mp3ish)).toBe('mpeg');
    expect(sniffContainer(adtsish)).toBe('adts');
  });

  it('returns null for bytes that are not audio', () => {
    expect(sniffContainer(notAudio)).toBeNull();
  });

  it('ignores the declared content type entirely', () => {
    // The parser takes only bytes; a lying Content-Type cannot steer it to a different format.
    expect(sniffContainer(wav(1))).toBe('wav');
    expect(audioDurationSeconds(wav(1))).toBeCloseTo(1, 3);
  });
});

describe('audioDurationSeconds', () => {
  it('reads mvhd duration ÷ timescale (version 0)', () => {
    expect(audioDurationSeconds(m4a(299))).toBeCloseTo(299, 3);
    expect(audioDurationSeconds(m4a(300))).toBeCloseTo(300, 3);
    expect(audioDurationSeconds(m4a(301))).toBeCloseTo(301, 3);
  });

  it('reads 64-bit mvhd duration (version 1)', () => {
    expect(audioDurationSeconds(m4a(300, { version: 1 }))).toBeCloseTo(300, 3);
  });

  it('is independent of byte size — a small file can be a long recording', () => {
    const long = m4a(660, { padBytes: 512 });
    expect(long.byteLength).toBeLessThan(4096);
    expect(audioDurationSeconds(long)).toBeCloseTo(660, 3);
  });

  it('measures WAV from the data chunk and byte rate', () => {
    expect(audioDurationSeconds(wav(30))).toBeCloseTo(30, 3);
  });

  it('measures constant-bitrate mp3 from its frame header', () => {
    expect(audioDurationSeconds(mp3(120))).toBeCloseTo(120, 0);
  });

  it('measures ADTS by counting frames', () => {
    // Frames hold 1024 samples, so the total quantizes to ~0.128 s at 8 kHz.
    expect(audioDurationSeconds(adts(120))).toBeCloseTo(120, 0);
  });

  describe('unreadable input fails closed', () => {
    it('rejects bytes that match no container', () => {
      expect(() => audioDurationSeconds(notAudio)).toThrow(UnreadableAudioError);
    });

    it('rejects an mvhd that declares an unknown duration', () => {
      expect(() => audioDurationSeconds(m4aUnknownDuration())).toThrow(UnreadableAudioError);
    });

    it('rejects a truncated container rather than guessing', () => {
      expect(() => audioDurationSeconds(m4a(300).subarray(0, 20))).toThrow(UnreadableAudioError);
    });

    it('rejects an empty buffer', () => {
      expect(() => audioDurationSeconds(Buffer.alloc(0))).toThrow(UnreadableAudioError);
    });

    it('terminates on a box that declares a size which cannot advance the walk', () => {
      // A zero-length box header would loop forever without the guard in the walker.
      const hostile = Buffer.concat([
        Buffer.from([0, 0, 0, 0]),
        Buffer.from('ftyp', 'latin1'),
        Buffer.alloc(64),
      ]);
      expect(() => audioDurationSeconds(hostile)).toThrow(UnreadableAudioError);
    });

    it('terminates on a moov whose child box claims a huge size', () => {
      const child = Buffer.alloc(16);
      child.writeUInt32BE(0xfffffff0, 0);
      child.write('mvhd', 4, 'latin1');
      const moov = Buffer.alloc(8);
      moov.writeUInt32BE(8 + child.length, 0);
      moov.write('moov', 4, 'latin1');
      const ftyp = Buffer.alloc(16);
      ftyp.writeUInt32BE(16, 0);
      ftyp.write('ftyp', 4, 'latin1');
      expect(() => audioDurationSeconds(Buffer.concat([ftyp, moov, child]))).toThrow(
        UnreadableAudioError,
      );
    });
  });
});

/**
 * The fixtures above are hand-built, so on their own they would only prove the parser agrees with
 * this file's idea of a container. These cases run genuine encoder output through it instead, and
 * skip where ffmpeg is unavailable rather than making it a hard test dependency.
 */
describe('agreement with real encoder output', () => {
  const hasFfmpeg = (() => {
    try {
      execFileSync('ffmpeg', ['-version'], { stdio: 'ignore' });
      return true;
    } catch {
      return false;
    }
  })();

  it.skipIf(!hasFfmpeg)('matches ffmpeg for each container we accept', () => {
    const dir = mkdtempSync(join(tmpdir(), 'astold-audio-'));
    try {
      const encode = (name: string, args: string[], seconds: number) => {
        const out = join(dir, name);
        execFileSync(
          'ffmpeg',
          ['-v', 'error', '-f', 'lavfi', '-i', `sine=frequency=440:duration=${seconds}`, ...args, out, '-y'],
          { stdio: 'ignore' },
        );
        return readFileSync(out);
      };

      // Includes a deliberately low-bitrate, long recording: the shape an abusive caller would use
      // to push hours of billable audio through while staying far under the byte cap.
      expect(audioDurationSeconds(encode('a.m4a', ['-c:a', 'aac', '-b:a', '64k'], 3))).toBeCloseTo(3, 0);
      const lowBitrate = encode('b.m4a', ['-c:a', 'aac', '-b:a', '8k', '-ar', '8000', '-ac', '1'], 660);
      expect(lowBitrate.byteLength).toBeLessThan(25 * 1024 * 1024);
      expect(audioDurationSeconds(lowBitrate)).toBeCloseTo(660, 0);

      expect(audioDurationSeconds(encode('c.wav', ['-c:a', 'pcm_s16le'], 3))).toBeCloseTo(3, 0);

      // libmp3lame is not in every ffmpeg build; skip that one format rather than the whole case.
      try {
        const asMp3 = encode('e.mp3', ['-c:a', 'libmp3lame', '-b:a', '64k'], 3);
        expect(audioDurationSeconds(asMp3)).toBeCloseTo(3, 0);
      } catch (err) {
        if (!(err as Error).message?.includes('Command failed')) throw err;
      }

      expect(audioDurationSeconds(encode('d.aac', ['-c:a', 'aac', '-f', 'adts'], 3))).toBeCloseTo(3, 0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
