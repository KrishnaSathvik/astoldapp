import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  MemoryAttestedKeyStore,
  SqliteAttestedKeyStore,
  type AttestedKeyStore,
  makeAttestedKeyStore,
} from '../src/security/attestedKeyStore.js';

const PEM = '-----BEGIN PUBLIC KEY-----\nAAAA\n-----END PUBLIC KEY-----';

/** Behaviour every store must have, whatever the backing medium. */
function sharedStoreContract(name: string, make: () => AttestedKeyStore) {
  describe(name, () => {
    let store: AttestedKeyStore;
    beforeEach(() => {
      store = make();
    });
    afterEach(() => store.close());

    it('returns undefined for a key that was never registered', () => {
      expect(store.get('nope')).toBeUndefined();
    });

    it('reads back a registered key and its counter', () => {
      store.put('k1', { publicKeyPem: PEM, signCount: 3 });
      expect(store.get('k1')).toEqual({ publicKeyPem: PEM, signCount: 3 });
    });

    it('advances the assertion counter', () => {
      store.put('k1', { publicKeyPem: PEM, signCount: 1 });
      store.updateSignCount('k1', 7);
      expect(store.get('k1')?.signCount).toBe(7);
    });

    it('re-registering a key id replaces the public key and resets the counter', () => {
      store.put('k1', { publicKeyPem: PEM, signCount: 9 });
      store.put('k1', { publicKeyPem: 'other-pem', signCount: 0 });
      expect(store.get('k1')).toEqual({ publicKeyPem: 'other-pem', signCount: 0 });
    });

    it('keeps key ids independent', () => {
      store.put('a', { publicKeyPem: PEM, signCount: 1 });
      store.put('b', { publicKeyPem: PEM, signCount: 2 });
      store.updateSignCount('a', 5);
      expect(store.get('a')?.signCount).toBe(5);
      expect(store.get('b')?.signCount).toBe(2);
    });
  });
}

sharedStoreContract('MemoryAttestedKeyStore', () => new MemoryAttestedKeyStore());
sharedStoreContract('SqliteAttestedKeyStore (in-memory)', () => new SqliteAttestedKeyStore(':memory:'));

describe('SqliteAttestedKeyStore durability', () => {
  let dir: string;
  let file: string;
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'astold-attest-'));
    file = join(dir, 'app-attest.db');
  });
  afterEach(() => rmSync(dir, { recursive: true, force: true }));

  it('survives a process restart with the counter intact', () => {
    const first = new SqliteAttestedKeyStore(file);
    first.put('k1', { publicKeyPem: PEM, signCount: 0 });
    first.updateSignCount('k1', 42);
    first.close();

    const reopened = new SqliteAttestedKeyStore(file); // simulates a relay restart
    expect(reopened.get('k1')).toEqual({ publicKeyPem: PEM, signCount: 42 });
    reopened.close();
  });

  it('creates the database directory when it does not exist yet', () => {
    const nested = join(dir, 'data', 'app-attest.db');
    const store = new SqliteAttestedKeyStore(nested);
    store.put('k1', { publicKeyPem: PEM, signCount: 0 });
    expect(store.get('k1')?.publicKeyPem).toBe(PEM);
    store.close();
  });
});

describe('makeAttestedKeyStore', () => {
  it('is durable when attestation is enforced', () => {
    const store = makeAttestedKeyStore({
      APP_ATTEST_REQUIRED: true,
      APP_ATTEST_DB_PATH: ':memory:',
    });
    expect(store).toBeInstanceOf(SqliteAttestedKeyStore);
    store.close();
  });

  it('stays in-process when attestation is off, so dev needs no database', () => {
    const store = makeAttestedKeyStore({ APP_ATTEST_REQUIRED: false });
    expect(store).toBeInstanceOf(MemoryAttestedKeyStore);
    store.close();
  });
});
