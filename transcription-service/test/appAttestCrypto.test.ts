import { describe, it, expect } from 'vitest';
import { Buffer } from 'node:buffer';
import { createHash, generateKeyPairSync, sign as nodeSign } from 'node:crypto';
import { encode as cborEncode } from 'cbor-x';
import {
  AppAttestError,
  parseAuthenticatorData,
  sha256,
  verifyAssertion,
} from '../src/security/appAttestCrypto.js';

const APP_ID = 'ABCDE12345.com.yourly.app';

function sha(...b: Buffer[]) {
  const h = createHash('sha256');
  for (const p of b) h.update(p);
  return h.digest();
}

/** Build assertion authenticatorData: rpIdHash(32) + flags(1) + signCount(4 BE). */
function authData(appId: string, signCount: number): Buffer {
  const rpIdHash = sha(Buffer.from(appId));
  const tail = Buffer.alloc(5);
  tail.writeUInt8(0, 0);
  tail.writeUInt32BE(signCount, 1);
  return Buffer.concat([rpIdHash, tail]);
}

describe('appAttestCrypto helpers', () => {
  it('sha256 matches node concatenation', () => {
    expect(sha256(Buffer.from('a'), Buffer.from('b')).equals(sha(Buffer.from('a'), Buffer.from('b')))).toBe(true);
  });

  it('parseAuthenticatorData reads rpIdHash/flags/signCount', () => {
    const ad = authData(APP_ID, 7);
    const p = parseAuthenticatorData(ad, false);
    expect(p.signCount).toBe(7);
    expect(p.flags).toBe(0);
    expect(p.rpIdHash.equals(sha(Buffer.from(APP_ID)))).toBe(true);
  });

  it('parseAuthenticatorData extracts attested credential data', () => {
    const base = authData(APP_ID, 0);
    const aaguid = Buffer.from('appattestdevelop');
    const credId = Buffer.from('credential-id-bytes');
    const len = Buffer.alloc(2);
    len.writeUInt16BE(credId.length, 0);
    const ad = Buffer.concat([base, aaguid, len, credId]);
    const p = parseAuthenticatorData(ad, true);
    expect(p.aaguid!.equals(aaguid)).toBe(true);
    expect(p.credentialId!.equals(credId)).toBe(true);
  });
});

describe('verifyAssertion (real P-256 round trip)', () => {
  function signedAssertion(signCount: number, clientDataHash: Buffer, keyPair: ReturnType<typeof generateKeyPairSync>) {
    const ad = authData(APP_ID, signCount);
    const nonce = sha(ad, clientDataHash);
    const signature = nodeSign('sha256', nonce, { key: keyPair.privateKey, dsaEncoding: 'der' });
    return Buffer.from(cborEncode({ signature, authenticatorData: ad }));
  }

  it('accepts a valid assertion and returns the new signCount', () => {
    const kp = generateKeyPairSync('ec', { namedCurve: 'P-256' });
    const publicKeyPem = kp.publicKey.export({ type: 'spki', format: 'pem' }).toString();
    const clientDataHash = sha(Buffer.from('request-payload'));
    const assertion = signedAssertion(5, clientDataHash, kp);

    const { signCount } = verifyAssertion({ assertion, clientDataHash, publicKeyPem, previousSignCount: 0, appId: APP_ID });
    expect(signCount).toBe(5);
  });

  it('rejects a replayed / non-increasing signCount', () => {
    const kp = generateKeyPairSync('ec', { namedCurve: 'P-256' });
    const publicKeyPem = kp.publicKey.export({ type: 'spki', format: 'pem' }).toString();
    const clientDataHash = sha(Buffer.from('p'));
    const assertion = signedAssertion(3, clientDataHash, kp);
    expect(() =>
      verifyAssertion({ assertion, clientDataHash, publicKeyPem, previousSignCount: 3, appId: APP_ID }),
    ).toThrow(AppAttestError);
  });

  it('rejects a wrong app id (rpIdHash mismatch)', () => {
    const kp = generateKeyPairSync('ec', { namedCurve: 'P-256' });
    const publicKeyPem = kp.publicKey.export({ type: 'spki', format: 'pem' }).toString();
    const clientDataHash = sha(Buffer.from('p'));
    const assertion = signedAssertion(1, clientDataHash, kp);
    expect(() =>
      verifyAssertion({ assertion, clientDataHash, publicKeyPem, previousSignCount: 0, appId: 'OTHER.app' }),
    ).toThrow(AppAttestError);
  });

  it('rejects a tampered signature', () => {
    const kp = generateKeyPairSync('ec', { namedCurve: 'P-256' });
    const other = generateKeyPairSync('ec', { namedCurve: 'P-256' });
    const publicKeyPem = other.publicKey.export({ type: 'spki', format: 'pem' }).toString(); // wrong key
    const clientDataHash = sha(Buffer.from('p'));
    const assertion = signedAssertion(1, clientDataHash, kp);
    expect(() =>
      verifyAssertion({ assertion, clientDataHash, publicKeyPem, previousSignCount: 0, appId: APP_ID }),
    ).toThrow(AppAttestError);
  });
});
