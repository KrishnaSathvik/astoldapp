import 'reflect-metadata'; // required by @peculiar/x509's tsyringe dependency
import { Buffer } from 'node:buffer';
import { createHash, createPublicKey, verify as nodeVerify, webcrypto } from 'node:crypto';
import { decode as cborDecode } from 'cbor-x';
import * as x509 from '@peculiar/x509';

x509.cryptoProvider.set(webcrypto as unknown as Parameters<typeof x509.cryptoProvider.set>[0]);

/** Apple App Attestation Root CA (public). Trust anchor for the attestation cert chain. */
const APPLE_APP_ATTEST_ROOT_CA = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`;

const APP_ATTEST_NONCE_OID = '1.2.840.113635.100.8.2';

export function sha256(...parts: Buffer[]): Buffer {
  const h = createHash('sha256');
  for (const p of parts) h.update(p);
  return h.digest();
}

export interface AuthenticatorData {
  rpIdHash: Buffer;
  flags: number;
  signCount: number;
  aaguid?: Buffer;
  credentialId?: Buffer;
}

/** Parse WebAuthn authenticator data. Attestation includes attested-credential data; assertion doesn't. */
export function parseAuthenticatorData(authData: Buffer, hasCredentialData: boolean): AuthenticatorData {
  if (authData.length < 37) throw new Error('authenticatorData too short');
  const rpIdHash = authData.subarray(0, 32);
  const flags = authData[32]!;
  const signCount = authData.readUInt32BE(33);
  if (!hasCredentialData) return { rpIdHash, flags, signCount };

  const aaguid = authData.subarray(37, 53);
  const credIdLen = authData.readUInt16BE(53);
  const credentialId = authData.subarray(55, 55 + credIdLen);
  return { rpIdHash, flags, signCount, aaguid, credentialId };
}

export class AppAttestError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AppAttestError';
  }
}

export interface AttestationResult {
  publicKeyPem: string; // stored to verify future assertions
  signCount: number;
}

/**
 * Verify an App Attest attestation object, per Apple's "Validating Apps That Connect to Your Server".
 * Returns the attested public key (for future assertions).
 */
export async function verifyAttestation(params: {
  attestation: Buffer;
  challenge: string;
  keyId: string; // base64, from the client
  appId: string; // "TEAMID.bundleId"
  requireProductionAAGUID?: boolean;
}): Promise<AttestationResult> {
  const obj = cborDecode(params.attestation) as {
    fmt?: string;
    attStmt?: { x5c?: Buffer[] };
    authData?: Buffer;
  };
  if (obj.fmt !== 'apple-appattest') throw new AppAttestError('unexpected attestation format');
  const x5c = obj.attStmt?.x5c;
  const authData = obj.authData ? Buffer.from(obj.authData) : undefined;
  if (!x5c || x5c.length < 2 || !authData) throw new AppAttestError('malformed attestation');

  // 1) Certificate chain: leaf → intermediate → Apple root.
  const leaf = new x509.X509Certificate(new Uint8Array(x5c[0]!));
  const intermediate = new x509.X509Certificate(new Uint8Array(x5c[1]!));
  const root = new x509.X509Certificate(APPLE_APP_ATTEST_ROOT_CA);
  const now = new Date();
  const leafOK = await leaf.verify({ publicKey: intermediate.publicKey, date: now });
  const interOK = await intermediate.verify({ publicKey: root.publicKey, date: now });
  if (!leafOK || !interOK) throw new AppAttestError('certificate chain verification failed');

  // 2) Nonce: SHA256(authData || SHA256(challenge)) must equal the leaf cert's nonce extension.
  const clientDataHash = sha256(Buffer.from(params.challenge, 'utf8'));
  const expectedNonce = sha256(authData, clientDataHash);
  const ext = leaf.getExtension(APP_ATTEST_NONCE_OID);
  if (!ext) throw new AppAttestError('missing nonce extension');
  const extBytes = Buffer.from(ext.value);
  const certNonce = extBytes.subarray(extBytes.length - 32); // trailing OCTET STRING (32 bytes)
  if (!expectedNonce.equals(certNonce)) throw new AppAttestError('nonce mismatch');

  // 3) authData checks.
  const parsed = parseAuthenticatorData(authData, true);
  if (!parsed.rpIdHash.equals(sha256(Buffer.from(params.appId, 'utf8')))) {
    throw new AppAttestError('rpIdHash != SHA256(appId)');
  }
  if (parsed.signCount !== 0) throw new AppAttestError('initial signCount must be 0');
  const aaguid = parsed.aaguid!;
  const devAAGUID = Buffer.from('appattestdevelop');
  const prodAAGUID = Buffer.concat([Buffer.from('appattest'), Buffer.alloc(7)]);
  const aaguidOK = params.requireProductionAAGUID
    ? aaguid.equals(prodAAGUID)
    : aaguid.equals(devAAGUID) || aaguid.equals(prodAAGUID);
  if (!aaguidOK) throw new AppAttestError('unexpected AAGUID');

  // 4) keyId must equal the attested credentialId.
  const credentialId = parsed.credentialId!;
  if (!Buffer.from(params.keyId, 'base64').equals(credentialId)) {
    throw new AppAttestError('keyId != credentialId');
  }

  // Export the leaf public key (SPKI DER) as PEM for future assertion verification.
  const spki = Buffer.from(leaf.publicKey.rawData);
  const publicKeyPem = createPublicKey({ key: spki, format: 'der', type: 'spki' })
    .export({ type: 'spki', format: 'pem' }).toString();

  return { publicKeyPem, signCount: parsed.signCount };
}

/**
 * Verify an App Attest assertion for a request. `clientDataHash` is SHA256 of the request payload the
 * client signed. Returns the new signCount (must strictly increase).
 */
export function verifyAssertion(params: {
  assertion: Buffer;
  clientDataHash: Buffer;
  publicKeyPem: string;
  previousSignCount: number;
  appId: string;
}): { signCount: number } {
  const obj = cborDecode(params.assertion) as { signature?: Buffer; authenticatorData?: Buffer };
  const signature = obj.signature ? Buffer.from(obj.signature) : undefined;
  const authData = obj.authenticatorData ? Buffer.from(obj.authenticatorData) : undefined;
  if (!signature || !authData) throw new AppAttestError('malformed assertion');

  // Signature is over SHA256(authenticatorData || clientDataHash).
  const nonce = sha256(authData, params.clientDataHash);
  const ok = nodeVerify(
    'sha256',
    nonce,
    { key: params.publicKeyPem, dsaEncoding: 'der' },
    signature,
  );
  if (!ok) throw new AppAttestError('assertion signature invalid');

  const parsed = parseAuthenticatorData(authData, false);
  if (!parsed.rpIdHash.equals(sha256(Buffer.from(params.appId, 'utf8')))) {
    throw new AppAttestError('rpIdHash != SHA256(appId)');
  }
  if (parsed.signCount <= params.previousSignCount) {
    throw new AppAttestError('signCount did not increase (possible replay)');
  }
  return { signCount: parsed.signCount };
}
