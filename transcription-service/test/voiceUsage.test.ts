import { describe, it, expect } from 'vitest';
import {
  MemoryVoiceUsageStore,
  SqliteVoiceUsageStore,
  periodFor,
  resetsAtFor,
  type VoiceUsageStore,
} from '../src/security/voiceUsage.js';

const CEILING = 3600; // 60 minutes

/**
 * The store's contract (docs/04-voice-transcription.md §14). Both implementations are held to the
 * same tests: the in-memory one is what dev and tests run on, and the SQLite one is what actually
 * protects the bill, so a behavioural difference between them is a bug in the one that ships.
 */
const implementations: [string, () => VoiceUsageStore][] = [
  ['MemoryVoiceUsageStore', () => new MemoryVoiceUsageStore(CEILING)],
  ['SqliteVoiceUsageStore', () => new SqliteVoiceUsageStore(':memory:', CEILING)],
];

describe.each(implementations)('%s', (_name, make) => {
  it('allows a recording on a fresh installation', () => {
    const store = make();
    expect(store.reserve('install-a', 60).allowed).toBe(true);
    store.close();
  });

  it('is a soft ceiling: the reservation that crosses the limit is allowed whole', () => {
    const store = make();
    expect(store.reserve('install-a', 3540).allowed).toBe(true); // 59m used
    expect(store.reserve('install-a', 60).allowed).toBe(true); // exactly 60m
    expect(store.reserve('install-a', 1).allowed).toBe(false); // next one refused
    store.close();
  });

  it('lets a full 5-minute recording finish from 59 minutes, then refuses the next', () => {
    const store = make();
    expect(store.reserve('install-a', 3540).allowed).toBe(true); // 59m
    expect(store.reserve('install-a', 300).allowed).toBe(true); // 64m — allowed entire
    expect(store.reserve('install-a', 1).allowed).toBe(false);
    store.close();
  });

  it('refuses at exactly the ceiling', () => {
    const store = make();
    expect(store.reserve('install-a', CEILING).allowed).toBe(true);
    const refused = store.reserve('install-a', 1);
    expect(refused.allowed).toBe(false);
    if (!refused.allowed) expect(refused.resetsAt).toMatch(/^\d{4}-\d{2}-01T00:00:00\.000Z$/);
    store.close();
  });

  it('a refund releases the reservation so the next recording is admitted', () => {
    const store = make();
    const first = store.reserve('install-a', 3540);
    expect(first.allowed).toBe(true);
    const second = store.reserve('install-a', 60); // now at the ceiling
    expect(second.allowed).toBe(true);
    if (!second.allowed) return;

    store.refund('install-a', second.period, 60); // transcription produced nothing
    expect(store.reserve('install-a', 60).allowed).toBe(true); // back under, admitted again
    store.close();
  });

  it('a refund cannot mint allowance beyond zero', () => {
    const store = make();
    const r = store.reserve('install-a', 60);
    expect(r.allowed).toBe(true);
    if (!r.allowed) return;

    store.refund('install-a', r.period, 100_000); // absurd over-refund
    expect(store.reserve('install-a', CEILING).allowed).toBe(true);
    expect(store.reserve('install-a', 1).allowed).toBe(false); // clamped at 0, not negative
    store.close();
  });

  it('refunding an installation that never reserved is a no-op', () => {
    const store = make();
    store.refund('never-seen', periodFor(Date.now()), 600);
    expect(store.reserve('never-seen', CEILING).allowed).toBe(true);
    expect(store.reserve('never-seen', 1).allowed).toBe(false);
    store.close();
  });

  it('keeps installations independent', () => {
    const store = make();
    expect(store.reserve('install-a', CEILING).allowed).toBe(true);
    expect(store.reserve('install-a', 1).allowed).toBe(false);
    expect(store.reserve('install-b', 60).allowed).toBe(true); // untouched by a's usage
    store.close();
  });

  it('starts a fresh bucket when the UTC month rolls over', () => {
    const store = make();
    const august = Date.UTC(2026, 7, 20, 12, 0, 0);
    const september = Date.UTC(2026, 8, 1, 0, 0, 1);

    expect(store.reserve('install-a', CEILING, august).allowed).toBe(true);
    expect(store.reserve('install-a', 1, august).allowed).toBe(false);
    expect(store.reserve('install-a', 60, september).allowed).toBe(true); // new period, zero used
    store.close();
  });

  it('refunds into the period the reservation was made in, not the current one', () => {
    const store = make();
    const august = Date.UTC(2026, 7, 31, 23, 59, 0);
    const september = Date.UTC(2026, 8, 1, 0, 0, 30);

    const r = store.reserve('install-a', CEILING, august);
    expect(r.allowed).toBe(true);
    if (!r.allowed) return;
    expect(r.period).toBe('2026-08');

    // The provider failed a minute later, in September. The refund must land on August.
    store.refund('install-a', r.period, CEILING);
    expect(store.reserve('install-a', 60, august).allowed).toBe(true); // August released
    expect(store.reserve('install-a', 60, september).allowed).toBe(true); // September untouched
    store.close();
  });

  it('reports exhaustion on the reservation that spends the allowance', () => {
    const store = make();
    const under = store.reserve('install-a', 3540); // 59m — plenty left
    expect(under.allowed && under.exhausted).toBe(false);

    const crossing = store.reserve('install-a', 300); // 64m — allowed whole, and that was the last
    expect(crossing.allowed).toBe(true);
    if (!crossing.allowed) return;
    expect(crossing.exhausted).toBe(true);
    expect(crossing.resetsAt).toMatch(/^\d{4}-\d{2}-01T00:00:00\.000Z$/);
    store.close();
  });

  it('reports exhaustion when a reservation lands exactly on the ceiling', () => {
    const store = make();
    store.reserve('install-a', 3540);
    const exact = store.reserve('install-a', 60); // exactly 3600
    expect(exact.allowed && exact.exhausted).toBe(true);
    store.close();
  });

  it('does not report exhaustion while there is allowance left', () => {
    const store = make();
    const r = store.reserve('install-a', 3599); // one second short
    expect(r.allowed && r.exhausted).toBe(false);
    store.close();
  });

  it('reports the reset as the start of the next UTC month', () => {
    const store = make();
    const december = Date.UTC(2026, 11, 15, 8, 0, 0);
    expect(store.reserve('install-a', CEILING, december).allowed).toBe(true);
    const refused = store.reserve('install-a', 1, december);
    expect(refused.allowed).toBe(false);
    if (!refused.allowed) expect(refused.resetsAt).toBe('2027-01-01T00:00:00.000Z'); // year rolls too
    store.close();
  });

  it('accounts for fractional durations without drifting', () => {
    const store = make();
    // Real containers do not hand back whole seconds; the counter carries what was measured.
    for (let i = 0; i < 12; i++) expect(store.reserve('install-a', 299.7, 0).allowed).toBe(true);
    // 3596.4 used — still under, so a thirteenth full recording is admitted whole and overshoots.
    expect(store.reserve('install-a', 299.7, 0).allowed).toBe(true);
    expect(store.reserve('install-a', 1, 0).allowed).toBe(false); // 3896.1 — the next one is refused
    store.close();
  });
});

describe('period arithmetic', () => {
  it('formats a UTC calendar month', () => {
    expect(periodFor(Date.UTC(2026, 7, 21, 23, 59, 59))).toBe('2026-08');
    expect(periodFor(Date.UTC(2026, 0, 1, 0, 0, 0))).toBe('2026-01');
  });

  it('buckets by UTC, not local time', () => {
    // 2026-09-01T00:30Z is still August in the Americas. The server does not care.
    expect(periodFor(Date.UTC(2026, 8, 1, 0, 30, 0))).toBe('2026-09');
  });

  it('resets at midnight UTC on the first of the next month', () => {
    expect(resetsAtFor(Date.UTC(2026, 7, 21, 12, 0, 0))).toBe('2026-09-01T00:00:00.000Z');
    expect(resetsAtFor(Date.UTC(2026, 11, 31, 23, 59, 59))).toBe('2027-01-01T00:00:00.000Z');
  });
});

describe('SqliteVoiceUsageStore durability', () => {
  it('stores no reversible install identity', () => {
    const store = new SqliteVoiceUsageStore(':memory:', CEILING);
    store.reserve('key-id-that-must-not-appear', 60);

    // Reach into the table the way an operator with the volume would.
    const db = (store as unknown as { db: { prepare: (s: string) => { all: () => unknown[] } } }).db;
    const rows = db.prepare('SELECT * FROM voice_usage').all() as Record<string, unknown>[];

    expect(rows).toHaveLength(1);
    expect(Object.keys(rows[0]!).sort()).toEqual([
      'identity_hash',
      'period',
      'updated_at',
      'used_seconds',
    ]);
    expect(JSON.stringify(rows[0])).not.toContain('key-id-that-must-not-appear');
    expect(rows[0]!.identity_hash).toMatch(/^[0-9a-f]{64}$/);
    store.close();
  });
});
