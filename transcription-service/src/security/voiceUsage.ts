import { createHash } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

/**
 * Monthly fair-use allowance for voice transcription (docs/04-voice-transcription.md §14).
 *
 * Voice is free and there is nothing to upgrade to, so this is not a quota product — it is the
 * ceiling that stops a free app with a paid dependency from being an unbounded bill. It is a *soft*
 * ceiling: the question asked before a recording is "is this installation under the limit?", never
 * "does it have enough left for this recording?", so a recording begun under the ceiling always
 * finishes. Only the next one is refused.
 *
 * The store holds four anonymous columns and no content: a hashed install id, a UTC month, seconds,
 * and a timestamp. Nothing here is derived from what was said — only from how long it lasted.
 */

/** The period a reservation was made against, so a refund lands in the same bucket. */
export type Period = string; // 'YYYY-MM', UTC

export type ReserveResult =
  | {
      allowed: true;
      period: Period;
      /**
       * This reservation took the installation to (or past) the ceiling, so the *next* recording
       * will be refused. Reported on the successful response so the app can stop the next
       * microphone tap before it opens, rather than discovering the ceiling by losing a spoken
       * thought to it. It is a boolean and a date — never a remaining-minutes figure, because a
       * number sent to the client is a number the interface eventually shows (RULES.md §1).
       */
      exhausted: boolean;
      /** Authoritative reset instant. The client renders it; it never computes one. */
      resetsAt: string;
    }
  /** Already at the ceiling. `resetsAt` is authoritative — the client never computes one. */
  | { allowed: false; resetsAt: string };

export interface VoiceUsageStore {
  /**
   * Charge `seconds` against this installation's current month, unless it is already at the
   * ceiling. Call this *before* the paid transcription and refund if no transcript comes back.
   */
  reserve(identity: string, seconds: number, now?: number): ReserveResult;
  /** Give back a reservation whose transcription did not produce text. */
  refund(identity: string, period: Period, seconds: number): void;
  close(): void;
}

/** UTC calendar month of an instant, e.g. `2026-08`. */
export function periodFor(now: number): Period {
  const d = new Date(now);
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

/** Start of the next UTC month — when this installation's allowance becomes available again. */
export function resetsAtFor(now: number): string {
  const d = new Date(now);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1)).toISOString();
}

/**
 * The attested key id identifies the installation, but this table has no need for a reversible
 * value — the key registry already holds the id it must hold, and this should not become a second
 * copy of it.
 */
function hashIdentity(identity: string): string {
  return createHash('sha256').update(identity).digest('hex');
}

/** Non-durable store — tests and the dev bypass. A counter that resets on restart enforces nothing. */
export class MemoryVoiceUsageStore implements VoiceUsageStore {
  private readonly used = new Map<string, number>();

  constructor(private readonly ceilingSeconds: number) {}

  reserve(identity: string, seconds: number, now: number = Date.now()): ReserveResult {
    const period = periodFor(now);
    const key = `${hashIdentity(identity)}|${period}`;
    const used = this.used.get(key) ?? 0;
    if (used >= this.ceilingSeconds) return { allowed: false, resetsAt: resetsAtFor(now) };
    const total = used + seconds;
    this.used.set(key, total);
    return {
      allowed: true,
      period,
      exhausted: total >= this.ceilingSeconds,
      resetsAt: resetsAtFor(now),
    };
  }

  refund(identity: string, period: Period, seconds: number): void {
    const key = `${hashIdentity(identity)}|${period}`;
    const used = this.used.get(key);
    if (used === undefined) return;
    this.used.set(key, Math.max(0, used - seconds));
  }

  close(): void {
    this.used.clear();
  }
}

/**
 * SQLite-backed store, sharing the mounted volume the attested-key registry already needs. A second
 * table, not a second service.
 *
 * `BEGIN IMMEDIATE` takes the write lock before the read, so a read-then-write pair cannot interleave
 * with another one: without it, two requests at 59 minutes could both observe "under the ceiling" and
 * both proceed. Node's sqlite binding is synchronous and the relay is single-threaded, so today the
 * event loop alone would serialise these — the transaction is what keeps that true if the relay ever
 * runs more than one instance against the volume.
 */
export class SqliteVoiceUsageStore implements VoiceUsageStore {
  private readonly db: DatabaseSync;

  constructor(
    path: string,
    private readonly ceilingSeconds: number,
  ) {
    if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
    this.db = new DatabaseSync(path);
    this.db.exec('PRAGMA journal_mode = WAL');
    this.db.exec('PRAGMA synchronous = FULL');
    this.db.exec('PRAGMA busy_timeout = 5000');
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS voice_usage (
        identity_hash TEXT    NOT NULL,
        period        TEXT    NOT NULL,
        used_seconds  REAL    NOT NULL,
        updated_at    INTEGER NOT NULL,
        PRIMARY KEY (identity_hash, period)
      )
    `);
  }

  reserve(identity: string, seconds: number, now: number = Date.now()): ReserveResult {
    const hash = hashIdentity(identity);
    const period = periodFor(now);

    this.db.exec('BEGIN IMMEDIATE');
    try {
      const row = this.db
        .prepare('SELECT used_seconds FROM voice_usage WHERE identity_hash = ? AND period = ?')
        .get(hash, period) as { used_seconds: number } | undefined;
      const used = row ? Number(row.used_seconds) : 0;

      if (used >= this.ceilingSeconds) {
        this.db.exec('ROLLBACK');
        return { allowed: false, resetsAt: resetsAtFor(now) };
      }

      this.db
        .prepare(
          `INSERT INTO voice_usage (identity_hash, period, used_seconds, updated_at)
           VALUES (?, ?, ?, ?)
           ON CONFLICT(identity_hash, period) DO UPDATE SET
             used_seconds = used_seconds + excluded.used_seconds,
             updated_at   = excluded.updated_at`,
        )
        .run(hash, period, seconds, now);

      this.db.exec('COMMIT');
      return {
        allowed: true,
        period,
        exhausted: used + seconds >= this.ceilingSeconds,
        resetsAt: resetsAtFor(now),
      };
    } catch (err) {
      this.db.exec('ROLLBACK');
      throw err;
    }
  }

  refund(identity: string, period: Period, seconds: number): void {
    // Clamped at zero so a refund can never mint allowance, and scoped to the period the
    // reservation was made in — a request straddling midnight on the 1st must not credit the new
    // month for time charged to the old one.
    this.db
      .prepare(
        `UPDATE voice_usage
            SET used_seconds = MAX(0, used_seconds - ?), updated_at = ?
          WHERE identity_hash = ? AND period = ?`,
      )
      .run(seconds, Date.now(), hashIdentity(identity), period);
  }

  close(): void {
    this.db.close();
  }
}

/** Durable whenever attestation is enforced, in-process otherwise — same rule as the key registry. */
export function makeVoiceUsageStore(config: {
  APP_ATTEST_REQUIRED: boolean;
  APP_ATTEST_DB_PATH?: string | undefined;
  MONTHLY_VOICE_SECONDS: number;
}): VoiceUsageStore {
  if (!config.APP_ATTEST_REQUIRED) return new MemoryVoiceUsageStore(config.MONTHLY_VOICE_SECONDS);
  if (!config.APP_ATTEST_DB_PATH) {
    throw new Error('APP_ATTEST_DB_PATH is required when APP_ATTEST_REQUIRED=true');
  }
  return new SqliteVoiceUsageStore(config.APP_ATTEST_DB_PATH, config.MONTHLY_VOICE_SECONDS);
}
