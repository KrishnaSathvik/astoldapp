import { describe, it, expect } from 'vitest';
import { InMemoryRateLimiter } from '../src/security/rateLimit.js';
import {
  AppAttestVerifier,
  AttestationError,
  DevBypassVerifier,
  makeVerifier,
} from '../src/security/attestation.js';

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

  it('makeVerifier picks dev bypass when not required, app attest when required', () => {
    expect(makeVerifier(false)).toBeInstanceOf(DevBypassVerifier);
    expect(makeVerifier(true)).toBeInstanceOf(AppAttestVerifier);
  });

  it('production verifier rejects unregistered/unverifiable requests', async () => {
    const v = new AppAttestVerifier();
    await expect(v.verifyRequest({ keyId: 'k', assertionBase64: 'a' })).rejects.toBeInstanceOf(
      AttestationError,
    );
  });

  it('production register rejects an unknown challenge', async () => {
    const v = new AppAttestVerifier();
    await expect(
      v.register({ keyId: 'k', attestationBase64: 'a', challenge: 'never-issued' }),
    ).rejects.toBeInstanceOf(AttestationError);
  });
});
