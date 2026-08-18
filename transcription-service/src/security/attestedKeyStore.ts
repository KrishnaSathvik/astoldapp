import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

/**
 * Registry of attested App Attest keys. Apple's assertion counter only defends against replay if it
 * is remembered *between* requests and *across* restarts, so this must be durable in production
 * (docs/05-architecture.md §16, RULES.md §3).
 *
 * It holds no note content and no user identity — a key id, a public key, and a counter.
 */
export interface AttestedKey {
  publicKeyPem: string;
  signCount: number;
}

export interface AttestedKeyStore {
  get(keyId: string): AttestedKey | undefined;
  /** Register (or re-register) a key. Re-registration replaces the key and resets the counter. */
  put(keyId: string, key: AttestedKey): void;
  /** Record the counter from a verified assertion. No-op for an unknown key. */
  updateSignCount(keyId: string, signCount: number): void;
  close(): void;
}

/** Non-durable store — tests and the dev bypass, never a deploy that enforces attestation. */
export class MemoryAttestedKeyStore implements AttestedKeyStore {
  private readonly keys = new Map<string, AttestedKey>();

  get(keyId: string): AttestedKey | undefined {
    const found = this.keys.get(keyId);
    return found ? { ...found } : undefined;
  }

  put(keyId: string, key: AttestedKey): void {
    this.keys.set(keyId, { ...key });
  }

  updateSignCount(keyId: string, signCount: number): void {
    const found = this.keys.get(keyId);
    if (found) found.signCount = signCount;
  }

  close(): void {
    this.keys.clear();
  }
}

/**
 * SQLite-backed store using Node's built-in `node:sqlite` — durable across restarts and deploys with
 * no added dependency. Point it at a mounted volume (see `fly.toml` `[mounts]`); `:memory:` gives an
 * ephemeral database for tests.
 *
 * `synchronous = FULL` is deliberate: a lost write here is a reusable assertion counter, and the
 * write volume is one small row per transcription.
 */
export class SqliteAttestedKeyStore implements AttestedKeyStore {
  private readonly db: DatabaseSync;

  constructor(path: string) {
    if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
    this.db = new DatabaseSync(path);
    this.db.exec('PRAGMA journal_mode = WAL');
    this.db.exec('PRAGMA synchronous = FULL');
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS attested_keys (
        key_id         TEXT PRIMARY KEY,
        public_key_pem TEXT    NOT NULL,
        sign_count     INTEGER NOT NULL,
        registered_at  INTEGER NOT NULL,
        last_seen_at   INTEGER NOT NULL
      )
    `);
  }

  get(keyId: string): AttestedKey | undefined {
    const row = this.db
      .prepare('SELECT public_key_pem, sign_count FROM attested_keys WHERE key_id = ?')
      .get(keyId) as { public_key_pem: string; sign_count: number } | undefined;
    if (!row) return undefined;
    return { publicKeyPem: row.public_key_pem, signCount: Number(row.sign_count) };
  }

  put(keyId: string, key: AttestedKey): void {
    const now = Date.now();
    this.db
      .prepare(
        `INSERT INTO attested_keys (key_id, public_key_pem, sign_count, registered_at, last_seen_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(key_id) DO UPDATE SET
           public_key_pem = excluded.public_key_pem,
           sign_count     = excluded.sign_count,
           registered_at  = excluded.registered_at,
           last_seen_at   = excluded.last_seen_at`,
      )
      .run(keyId, key.publicKeyPem, key.signCount, now, now);
  }

  updateSignCount(keyId: string, signCount: number): void {
    this.db
      .prepare('UPDATE attested_keys SET sign_count = ?, last_seen_at = ? WHERE key_id = ?')
      .run(signCount, Date.now(), keyId);
  }

  close(): void {
    this.db.close();
  }
}

/**
 * Pick the registry from config: durable whenever attestation is enforced, in-process otherwise.
 * `loadConfig` already guarantees a path is present when enforcement is on.
 */
export function makeAttestedKeyStore(config: {
  APP_ATTEST_REQUIRED: boolean;
  APP_ATTEST_DB_PATH?: string | undefined;
}): AttestedKeyStore {
  if (!config.APP_ATTEST_REQUIRED) return new MemoryAttestedKeyStore();
  if (!config.APP_ATTEST_DB_PATH) {
    throw new Error('APP_ATTEST_DB_PATH is required when APP_ATTEST_REQUIRED=true');
  }
  return new SqliteAttestedKeyStore(config.APP_ATTEST_DB_PATH);
}
