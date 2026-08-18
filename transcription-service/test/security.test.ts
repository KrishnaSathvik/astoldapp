import { describe, it, expect } from 'vitest';
import { Buffer } from 'node:buffer';
import { InMemoryRateLimiter } from '../src/security/rateLimit.js';
import {
  AppAttestVerifier,
  AttestationError,
  DevBypassVerifier,
  makeVerifier,
} from '../src/security/attestation.js';
import { MemoryAttestedKeyStore } from '../src/security/attestedKeyStore.js';

describe('InMemoryRateLimiter', () => {
  it('allows up to max then blocks within the window', () => {
    let now = 1000;
    const limiter = new InMemoryRateLimiter(2, 1000, () => now);
    expect(limiter.take('id')).toBe(true);
    expect(limiter.take('id')).toBe(true);
    expect(limiter.take('id')).toBe(false); // over the limit
    now += 1001; // window elapses
    expect(limiter.take('id')).toBe(true);
  });

  it('tracks identities independently', () => {
    const limiter = new InMemoryRateLimiter(1, 1000);
    expect(limiter.take('a')).toBe(true);
    expect(limiter.take('a')).toBe(false);
    expect(limiter.take('b')).toBe(true);
  });
});

describe('attestation', () => {
  it('dev bypass yields an identity and issues/consumes challenges', async () => {
    const v = new DevBypassVerifier();
    const { challenge } = v.issueChallenge();
    expect(challenge).toBeTypeOf('string');
    const { identity } = await v.verifyRequest({ keyId: 'k1' });
    expect(identity).toBe('k1');
  });

  const APP_ID = 'ABCDE12345.com.astold.app';

  it('makeVerifier picks dev bypass when not required, app attest when required', () => {
    expect(makeVerifier(false)).toBeInstanceOf(DevBypassVerifier);
    expect(makeVerifier(true, APP_ID)).toBeInstanceOf(AppAttestVerifier);
  });

  it('makeVerifier throws when App Attest required without an app id', () => {
    expect(() => makeVerifier(true)).toThrow();
  });

  it('production verifier rejects an unknown/expired challenge on assertion', async () => {
    const v = new AppAttestVerifier(APP_ID);
    await expect(
      v.verifyRequest({ keyId: 'k', assertionBase64: 'a', challenge: 'never-issued' }),
    ).rejects.toBeInstanceOf(AttestationError);
  });

  it('production register rejects an unknown challenge', async () => {
    const v = new AppAttestVerifier(APP_ID);
    await expect(
      v.register({ keyId: 'k', attestationBase64: 'a', challenge: 'never-issued' }),
    ).rejects.toBeInstanceOf(AttestationError);
  });

  it('register with a valid challenge but garbage attestation fails cleanly', async () => {
    const v = new AppAttestVerifier(APP_ID);
    const { challenge } = v.issueChallenge();
    await expect(
      v.register({ keyId: Buffer.from('k').toString('base64'), attestationBase64: Buffer.from('nope').toString('base64'), challenge }),
    ).rejects.toBeInstanceOf(AttestationError);
  });
});

describe('attested key persistence', () => {
  const APP_ID = 'ABCDE12345.com.astold.app';

  /** Attempt an assertion and return the error, so tests can tell "unknown key" from later checks. */
  async function assertionError(v: AppAttestVerifier): Promise<Error> {
    const { challenge } = v.issueChallenge();
    return v
      .verifyRequest({ keyId: 'k1', assertionBase64: Buffer.from('nope').toString('base64'), challenge })
      .then(() => new Error('expected a rejection'), (err: Error) => err);
  }

  it('rejects an assertion for a key the store has never seen', async () => {
    const v = new AppAttestVerifier(APP_ID, false, new MemoryAttestedKeyStore());
    expect((await assertionError(v)).message).toBe('unknown key');
  });

  it('recognises a key held in a store that outlives the verifier', async () => {
    const store = new MemoryAttestedKeyStore(); // stands in for the durable store across a restart
    store.put('k1', { publicKeyPem: 'pem', signCount: 4 });

    const restarted = new AppAttestVerifier(APP_ID, false, store);

    // The key is known, so verification proceeds to the signature rather than stopping at lookup.
    expect((await assertionError(restarted)).message).not.toBe('unknown key');
  });

  it('defaults to a non-durable store so tests and dev never need a database', () => {
    expect(new AppAttestVerifier(APP_ID)).toBeInstanceOf(AppAttestVerifier);
  });
});

describe('makeVerifier wiring', () => {
  const APP_ID = 'ABCDE12345.com.astold.app';

  it('hands the given key store to the production verifier', async () => {
    const store = new MemoryAttestedKeyStore();
    store.put('k1', { publicKeyPem: 'pem', signCount: 0 });
    const v = makeVerifier(true, APP_ID, false, store);

    const { challenge } = v.issueChallenge();
    const err = await v
      .verifyRequest({ keyId: 'k1', assertionBase64: Buffer.from('nope').toString('base64'), challenge })
      .then(() => new Error('expected a rejection'), (e: Error) => e);

    expect(err.message).not.toBe('unknown key');
  });
});
