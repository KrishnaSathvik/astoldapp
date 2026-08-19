/**
 * Authoritative audio duration measurement for the relay.
 *
 * Why this exists: transcription is billed per *minute*, but the only thing the request pipeline
 * could previously bound was *bytes*. Those are not the same — 25 MB of 8 kbps AAC is several hours
 * of audio. `MAX_DURATION_SECONDS` is the product limit (10 minutes), and it can only be enforced by
 * reading the duration out of the uploaded container itself.
 *
 * Two rules follow from that, and neither is negotiable:
 *
 *  1. **The duration is measured here, from the bytes.** A client-supplied duration field, form
 *     value, or header is never consulted — a caller trying to run up the bill would simply lie.
 *  2. **The container is identified by its magic bytes, not by `Content-Type`.** The declared MIME
 *     type is attacker-controlled in exactly the same way; it is used for the allowlist check
 *     (which is about what we accept), never to decide how to parse.
 *
 * When the duration cannot be established, callers must reject the request. Failing open would
 * reintroduce the unbounded-minutes hole this module exists to close.
 */

/** The duration could not be established from the bytes — callers must reject, never assume. */
export class UnreadableAudioError extends Error {
  constructor(readonly reason: string) {
    super(`unreadable audio: ${reason}`);
    this.name = 'UnreadableAudioError';
  }
}

/** Container families we can measure. Mirrors `ALLOWED_AUDIO_MIME` in config.ts. */
export type AudioContainer = 'mp4' | 'wav' | 'mpeg' | 'adts';

/** Guard rails for walking untrusted input: no unbounded loops, no unbounded recursion. */
const MAX_BOX_DEPTH = 8;
const MAX_BOXES = 4096;
const MAX_ADTS_FRAMES = 2_000_000;
const MAX_SYNC_SCAN = 1 << 16; // 64 KiB — a frame sync further in than this is not a media file

/**
 * Identify the container from its leading bytes. Returns null when nothing matches.
 *
 * MPEG-1 audio and ADTS AAC share the same 0xFF sync prefix, so they are told apart by the layer
 * field: ADTS always encodes layer `00`, which is reserved (and therefore never used) in MPEG audio.
 */
export function sniffContainer(buf: Buffer): AudioContainer | null {
  if (buf.length < 12) return null;

  if (buf.toString('latin1', 0, 4) === 'RIFF' && buf.toString('latin1', 8, 12) === 'WAVE') {
    return 'wav';
  }
  // ISO base media (m4a/mp4). `ftyp` is the first box of every well-formed file.
  if (buf.toString('latin1', 4, 8) === 'ftyp') return 'mp4';
  if (buf.toString('latin1', 0, 3) === 'ID3') return 'mpeg';

  if (buf[0] === 0xff && (buf[1]! & 0xe0) === 0xe0) {
    return (buf[1]! & 0x06) === 0x00 ? 'adts' : 'mpeg';
  }
  return null;
}

/**
 * Duration of `buf` in seconds, measured from the container.
 *
 * @throws {UnreadableAudioError} when the format is unrecognized or the headers do not yield a
 * duration. Never returns a guess, and never returns a value derived from the byte count alone.
 */
export function audioDurationSeconds(buf: Buffer): number {
  const container = sniffContainer(buf);
  if (container === null) throw new UnreadableAudioError('unrecognized container');

  const seconds =
    container === 'mp4'
      ? mp4Duration(buf)
      : container === 'wav'
        ? wavDuration(buf)
        : container === 'mpeg'
          ? mpegDuration(buf)
          : adtsDuration(buf);

  if (!Number.isFinite(seconds) || seconds <= 0) {
    throw new UnreadableAudioError(`${container}: no usable duration`);
  }
  return seconds;
}

// ---------------------------------------------------------------------------
// ISO base media file format (m4a / mp4 / aac-in-mp4)
// ---------------------------------------------------------------------------

/**
 * Read `moov/mvhd` (duration ÷ timescale). If the movie header carries no usable duration — some
 * muxers leave it 0 or "unknown" — fall back to the longest track header (`mdia/mdhd`), which is
 * what the playback duration actually is.
 */
function mp4Duration(buf: Buffer): number {
  const found: number[] = [];
  let boxes = 0;

  const walk = (start: number, end: number, depth: number): void => {
    let offset = start;
    while (offset + 8 <= end) {
      if (++boxes > MAX_BOXES) return;

      let size = buf.readUInt32BE(offset);
      const type = buf.toString('latin1', offset + 4, offset + 8);
      let header = 8;

      if (size === 1) {
        // 64-bit `largesize`. Anything beyond 2^53 is not a real file; treat it as malformed.
        if (offset + 16 > end) return;
        const large = buf.readBigUInt64BE(offset + 8);
        if (large > BigInt(Number.MAX_SAFE_INTEGER)) return;
        size = Number(large);
        header = 16;
      } else if (size === 0) {
        size = end - offset; // "extends to end of file"
      }

      // A box that does not advance past its own header would loop forever.
      if (size < header || offset + size > end) return;

      const body = offset + header;
      const bodyEnd = offset + size;

      if (type === 'mvhd' || type === 'mdhd') {
        const seconds = headerDuration(buf, body, bodyEnd);
        if (seconds !== null) found.push(seconds);
      } else if (
        depth < MAX_BOX_DEPTH &&
        (type === 'moov' || type === 'trak' || type === 'mdia')
      ) {
        walk(body, bodyEnd, depth + 1);
      }

      offset = bodyEnd;
    }
  };

  walk(0, buf.length, 0);

  if (found.length === 0) throw new UnreadableAudioError('mp4: no mvhd/mdhd duration');
  return Math.max(...found);
}

/**
 * `mvhd` and `mdhd` share a layout for the fields we need: version/flags, two timestamps, then
 * timescale and duration. Version 1 widens the timestamps and the duration to 64 bits.
 */
function headerDuration(buf: Buffer, body: number, bodyEnd: number): number | null {
  if (body + 4 > bodyEnd) return null;
  const version = buf[body]!;

  let timescale: number;
  let duration: number;

  if (version === 1) {
    if (body + 4 + 8 + 8 + 4 + 8 > bodyEnd) return null;
    timescale = buf.readUInt32BE(body + 20);
    const raw = buf.readBigUInt64BE(body + 24);
    // 0xFFFF…FFFF is the documented "unknown duration" sentinel.
    if (raw === 0xffffffffffffffffn || raw > BigInt(Number.MAX_SAFE_INTEGER)) return null;
    duration = Number(raw);
  } else if (version === 0) {
    if (body + 4 + 4 + 4 + 4 + 4 > bodyEnd) return null;
    timescale = buf.readUInt32BE(body + 12);
    duration = buf.readUInt32BE(body + 16);
    if (duration === 0xffffffff) return null;
  } else {
    return null;
  }

  if (timescale === 0 || duration === 0) return null;
  return duration / timescale;
}

// ---------------------------------------------------------------------------
// RIFF / WAVE
// ---------------------------------------------------------------------------

/** `data` chunk size ÷ byte rate. The byte rate is recomputed when `fmt ` reports a bogus one. */
function wavDuration(buf: Buffer): number {
  let offset = 12;
  let byteRate = 0;
  let dataBytes = 0;
  let chunks = 0;

  while (offset + 8 <= buf.length && ++chunks <= MAX_BOXES) {
    const id = buf.toString('latin1', offset, offset + 4);
    const size = buf.readUInt32LE(offset + 4);
    const body = offset + 8;

    if (id === 'fmt ' && body + 16 <= buf.length) {
      const channels = buf.readUInt16LE(body + 2);
      const sampleRate = buf.readUInt32LE(body + 4);
      const declaredByteRate = buf.readUInt32LE(body + 8);
      const bitsPerSample = buf.readUInt16LE(body + 14);
      byteRate =
        declaredByteRate > 0
          ? declaredByteRate
          : (sampleRate * channels * Math.max(bitsPerSample, 8)) / 8;
    } else if (id === 'data') {
      // A streamed file can declare size 0 (or overstate it); the bytes actually present win.
      const available = buf.length - body;
      dataBytes = size > 0 ? Math.min(size, available) : available;
    }

    // Chunks are word-aligned: an odd size is followed by a pad byte.
    const advance = 8 + size + (size % 2);
    if (advance <= 8) break;
    offset += advance;
  }

  if (byteRate <= 0) throw new UnreadableAudioError('wav: no byte rate');
  if (dataBytes <= 0) throw new UnreadableAudioError('wav: no data chunk');
  return dataBytes / byteRate;
}

// ---------------------------------------------------------------------------
// MPEG-1/2/2.5 audio (mp3)
// ---------------------------------------------------------------------------

const MPEG_BITRATES_V1_L3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0];
const MPEG_BITRATES_V2_L3 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0];
const MPEG_SAMPLE_RATES: Record<number, number[]> = {
  3: [44100, 48000, 32000], // MPEG-1
  2: [22050, 24000, 16000], // MPEG-2
  0: [11025, 12000, 8000], // MPEG-2.5
};

/**
 * Prefer the Xing/Info/VBRI frame count — it is exact and survives variable bitrate. Only when no
 * such header exists do we fall back to constant-bitrate arithmetic over the remaining bytes.
 */
function mpegDuration(buf: Buffer): number {
  const start = skipID3v2(buf);
  const sync = findMpegSync(buf, start);
  if (sync === null) throw new UnreadableAudioError('mpeg: no frame sync');

  const frame = parseMpegHeader(buf, sync);
  if (frame === null) throw new UnreadableAudioError('mpeg: bad frame header');

  const vbrFrames = readVbrFrameCount(buf, sync, frame);
  if (vbrFrames !== null) return (vbrFrames * frame.samplesPerFrame) / frame.sampleRate;

  if (frame.bitrateKbps <= 0) throw new UnreadableAudioError('mpeg: free-format bitrate');
  return ((buf.length - sync) * 8) / (frame.bitrateKbps * 1000);
}

/** ID3v2 length is stored as four 7-bit "syncsafe" bytes so it can never contain a false sync. */
function skipID3v2(buf: Buffer): number {
  if (buf.length < 10 || buf.toString('latin1', 0, 3) !== 'ID3') return 0;
  const size =
    ((buf[6]! & 0x7f) << 21) | ((buf[7]! & 0x7f) << 14) | ((buf[8]! & 0x7f) << 7) | (buf[9]! & 0x7f);
  const end = 10 + size;
  return end > 0 && end < buf.length ? end : 0;
}

function findMpegSync(buf: Buffer, from: number): number | null {
  const limit = Math.min(buf.length - 4, from + MAX_SYNC_SCAN);
  for (let i = from; i <= limit; i++) {
    if (buf[i] === 0xff && (buf[i + 1]! & 0xe0) === 0xe0 && parseMpegHeader(buf, i) !== null) {
      return i;
    }
  }
  return null;
}

interface MpegFrame {
  versionBits: number;
  sampleRate: number;
  bitrateKbps: number;
  samplesPerFrame: number;
  channels: number;
}

function parseMpegHeader(buf: Buffer, at: number): MpegFrame | null {
  if (at + 4 > buf.length) return null;
  const b1 = buf[at + 1]!;
  const b2 = buf[at + 2]!;
  const b3 = buf[at + 3]!;

  const versionBits = (b1 >> 3) & 0x03; // 3 = MPEG-1, 2 = MPEG-2, 0 = MPEG-2.5, 1 = reserved
  const layerBits = (b1 >> 1) & 0x03; // 1 = Layer III
  if (versionBits === 1 || layerBits === 0) return null;

  const rates = MPEG_SAMPLE_RATES[versionBits];
  const sampleRateIndex = (b2 >> 2) & 0x03;
  if (!rates || sampleRateIndex === 3) return null;
  const sampleRate = rates[sampleRateIndex]!;

  const bitrateIndex = (b2 >> 4) & 0x0f;
  if (bitrateIndex === 15) return null; // reserved
  const table = versionBits === 3 ? MPEG_BITRATES_V1_L3 : MPEG_BITRATES_V2_L3;
  const bitrateKbps = table[bitrateIndex]!;

  // Layer I is 384 samples; Layers II/III are 1152, halved for MPEG-2/2.5 Layer III.
  const samplesPerFrame =
    layerBits === 3 ? 384 : layerBits === 1 && versionBits !== 3 ? 576 : 1152;

  const channels = ((b3 >> 6) & 0x03) === 3 ? 1 : 2;
  return { versionBits, sampleRate, bitrateKbps, samplesPerFrame, channels };
}

/** Xing/Info sits after the side-information block; VBRI sits at a fixed offset of 32 bytes. */
function readVbrFrameCount(buf: Buffer, sync: number, frame: MpegFrame): number | null {
  const sideInfo =
    frame.versionBits === 3
      ? frame.channels === 1
        ? 17
        : 32
      : frame.channels === 1
        ? 9
        : 17;

  const xing = sync + 4 + sideInfo;
  if (xing + 12 <= buf.length) {
    const tag = buf.toString('latin1', xing, xing + 4);
    if (tag === 'Xing' || tag === 'Info') {
      const flags = buf.readUInt32BE(xing + 4);
      if ((flags & 0x01) !== 0) {
        const frames = buf.readUInt32BE(xing + 8);
        if (frames > 0) return frames;
      }
    }
  }

  const vbri = sync + 4 + 32;
  if (vbri + 20 <= buf.length && buf.toString('latin1', vbri, vbri + 4) === 'VBRI') {
    const frames = buf.readUInt32BE(vbri + 14);
    if (frames > 0) return frames;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Raw ADTS AAC
// ---------------------------------------------------------------------------

const ADTS_SAMPLE_RATES = [
  96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350,
];

/**
 * ADTS carries no duration field, so the frames are counted. Each frame declares its own length,
 * which keeps the walk linear and lets variable-bitrate streams measure exactly.
 */
function adtsDuration(buf: Buffer): number {
  let offset = 0;
  let samples = 0;
  let sampleRate = 0;
  let frames = 0;

  while (offset + 7 <= buf.length && frames < MAX_ADTS_FRAMES) {
    if (buf[offset] !== 0xff || (buf[offset + 1]! & 0xf6) !== 0xf0) break;

    const rateIndex = (buf[offset + 2]! >> 2) & 0x0f;
    const rate = ADTS_SAMPLE_RATES[rateIndex];
    if (rate === undefined) break;
    if (sampleRate === 0) sampleRate = rate;

    const frameLength =
      ((buf[offset + 3]! & 0x03) << 11) | (buf[offset + 4]! << 3) | (buf[offset + 5]! >> 5);
    if (frameLength < 7) break; // cannot advance — malformed

    // Each frame holds 1..4 raw data blocks of 1024 samples.
    samples += ((buf[offset + 6]! & 0x03) + 1) * 1024;
    offset += frameLength;
    frames++;
  }

  if (frames === 0 || sampleRate === 0) throw new UnreadableAudioError('adts: no frames');
  return samples / sampleRate;
}
