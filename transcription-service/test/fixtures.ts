import { Buffer } from 'node:buffer';

/**
 * Synthetic audio containers with an exact, known duration.
 *
 * Boundary cases (599 / 600 / 601 seconds) have to be exact, and no encoder will hand you exactly
 * 600.000 s — real files land a frame or two either side of the value you asked for. So these are
 * built field by field: the duration a test asks for is the duration written into the header.
 *
 * `test/audioDuration.test.ts` cross-checks the parser against genuine ffmpeg output where ffmpeg is
 * available, so these fixtures cannot quietly drift into a private dialect the real world never emits.
 */

function box(type: string, body: Buffer): Buffer {
  const header = Buffer.alloc(8);
  header.writeUInt32BE(8 + body.length, 0);
  header.write(type, 4, 'latin1');
  return Buffer.concat([header, body]);
}

/**
 * ISO base media (m4a) carrying `moov/mvhd`.
 *
 * @param seconds duration to encode.
 * @param padBytes size of the trailing `mdat`, to model a given bitrate — this is what lets a test
 * assert that a *long* recording is rejected while staying far *under* the byte cap.
 */
export function m4a(
  seconds: number,
  { timescale = 1000, padBytes = 0, version = 0 as 0 | 1 } = {},
): Buffer {
  const ftyp = box('ftyp', Buffer.concat([Buffer.from('M4A ', 'latin1'), Buffer.alloc(8)]));

  // mvhd: version/flags, timestamps, timescale, duration, then the fixed tail (rate, volume,
  // reserved, matrix, predefined, next track id) that real files always carry.
  const head = Buffer.alloc(version === 1 ? 24 : 16);
  head[0] = version;
  if (version === 1) {
    head.writeUInt32BE(timescale, 20);
  } else {
    head.writeUInt32BE(timescale, 12);
  }
  const duration = Math.round(seconds * timescale);
  const durationField = Buffer.alloc(version === 1 ? 8 : 4);
  if (version === 1) durationField.writeBigUInt64BE(BigInt(duration));
  else durationField.writeUInt32BE(duration);

  const tail = Buffer.alloc(80);
  tail.writeUInt32BE(0x00010000, 0); // rate 1.0
  tail.writeUInt16BE(0x0100, 4); // volume 1.0

  const moov = box('moov', box('mvhd', Buffer.concat([head, durationField, tail])));
  const mdat = box('mdat', Buffer.alloc(padBytes));
  return Buffer.concat([ftyp, moov, mdat]);
}

/** An m4a whose `mvhd` declares the "unknown duration" sentinel — measurable length: none. */
export function m4aUnknownDuration(): Buffer {
  const ftyp = box('ftyp', Buffer.concat([Buffer.from('M4A ', 'latin1'), Buffer.alloc(8)]));
  const body = Buffer.alloc(100);
  body.writeUInt32BE(1000, 12); // timescale
  body.writeUInt32BE(0xffffffff, 16); // duration = unknown
  return Buffer.concat([ftyp, box('moov', box('mvhd', body)), box('mdat', Buffer.alloc(64))]);
}

/** RIFF/WAVE with PCM data sized to `seconds`. */
export function wav(seconds: number, { sampleRate = 8000, channels = 1, bits = 16 } = {}): Buffer {
  const byteRate = (sampleRate * channels * bits) / 8;
  const dataBytes = Math.round(seconds * byteRate);

  const fmt = Buffer.alloc(16);
  fmt.writeUInt16LE(1, 0); // PCM
  fmt.writeUInt16LE(channels, 2);
  fmt.writeUInt32LE(sampleRate, 4);
  fmt.writeUInt32LE(byteRate, 8);
  fmt.writeUInt16LE((channels * bits) / 8, 12);
  fmt.writeUInt16LE(bits, 14);

  const riffBody = Buffer.concat([
    Buffer.from('WAVE', 'latin1'),
    riffChunk('fmt ', fmt),
    riffChunk('data', Buffer.alloc(dataBytes)),
  ]);
  const header = Buffer.alloc(8);
  header.write('RIFF', 0, 'latin1');
  header.writeUInt32LE(riffBody.length, 4);
  return Buffer.concat([header, riffBody]);
}

function riffChunk(id: string, body: Buffer): Buffer {
  const header = Buffer.alloc(8);
  header.write(id, 0, 'latin1');
  header.writeUInt32LE(body.length, 4);
  return Buffer.concat([header, body, body.length % 2 ? Buffer.alloc(1) : Buffer.alloc(0)]);
}

/** Raw ADTS AAC: `seconds` worth of 1024-sample frames at a chosen (low) bitrate. */
export function adts(seconds: number, { sampleRate = 8000, frameBytes = 24 } = {}): Buffer {
  const rateIndex = [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350]
    .indexOf(sampleRate);
  if (rateIndex < 0) throw new Error(`unsupported ADTS sample rate: ${sampleRate}`);

  const frameCount = Math.round((seconds * sampleRate) / 1024);
  const frame = Buffer.alloc(frameBytes);
  frame[0] = 0xff;
  frame[1] = 0xf1; // MPEG-4, no CRC
  frame[2] = ((0x01 << 6) | (rateIndex << 2) | 0x00) & 0xff; // AAC-LC, rate index
  frame[3] = ((1 << 6) | ((frameBytes >> 11) & 0x03)) & 0xff; // 1 channel + length hi
  frame[4] = (frameBytes >> 3) & 0xff;
  frame[5] = ((frameBytes & 0x07) << 5) | 0x1f;
  frame[6] = 0xfc; // one raw data block

  return Buffer.concat(Array.from({ length: frameCount }, () => frame));
}

/**
 * Constant-bitrate MPEG-2 Layer III (mp3) with no Xing header, so the parser has to fall back to
 * bitrate arithmetic. Low bitrate on purpose: long recordings stay small enough to hold in memory.
 */
export function mp3(seconds: number, { bitrateKbps = 8, sampleRate = 16000 } = {}): Buffer {
  if (bitrateKbps !== 8 || sampleRate !== 16000) {
    throw new Error('fixture covers MPEG-2 Layer III at 8 kbps / 16 kHz only');
  }
  const frameBytes = Math.floor((72 * bitrateKbps * 1000) / sampleRate); // 36
  const samplesPerFrame = 576;
  const frameCount = Math.round((seconds * sampleRate) / samplesPerFrame);

  const frame = Buffer.alloc(frameBytes);
  frame[0] = 0xff;
  frame[1] = 0xf3; // MPEG-2, Layer III, no CRC
  frame[2] = 0x18; // bitrate index 1 (8 kbps), sample-rate index 2 (16 kHz), no padding
  frame[3] = 0xc0; // single channel

  return Buffer.concat(Array.from({ length: frameCount }, () => frame));
}

/** Bytes that are not any audio container we know — the "unreadable" case. */
export const notAudio = Buffer.from('fake-audio-bytes');

/** A short, valid recording for tests that only need the happy path. */
export const validAudio = m4a(4);
