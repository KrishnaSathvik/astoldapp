import { createHash, randomUUID } from 'node:crypto';
import { Buffer } from 'node:buffer';
import {
  AppAttestError,
  verifyAssertion,
  verifyAttestation,
} from './appAttestCrypto.js';
import {
  MemoryAttestedKeyStore,
  type AttestedKeyStore,
} from './attestedKeyStore.js';

/**
 * App Attest boundary. Verifies that a request originates from a legitimate app instance so third
 * parties cannot copy the public endpoint and burn paid transcription (docs/05-architecture.md §16,
 * RULES.md §3). This is anti-abuse, NOT user authentication.
 */
export interface AttestationVerifier {
  /** Issue a one-time challenge the client attests against. */
  issueChallenge(): { challenge: string; expiresAt: number };
  /** Register an attested key (returns an anonymous install id). Throws on invalid attestation. */
  register(input: RegisterInput): Promise<{ installId: string }>;
  /** Verify a per-request assertion. Returns a stable identity used for rate limiting. */
  verifyRequest(headers: AttestationHeaders): Promise<{ identity: string }>;
}

export interface RegisterInput {
  keyId: string;
  attestationBase64: string;
  challenge: string;
}

export interface AttestationHeaders {
  keyId?: string | undefined;
  assertionBase64?: string | undefined;
  challenge?: string | undefined;
}

export class AttestationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AttestationError';
  }
}

/** In-memory challenge store (swap for Redis in production). */
class ChallengeStore {
  private readonly items = new Map<string, number>();
  private readonly ttlMs: number;
  constructor(ttlSeconds = 300) {
    this.ttlMs = ttlSeconds * 1000;
  }
  issue(): { challenge: string; expiresAt: number } {
    const challenge = randomUUID();
    const expiresAt = Date.now() + this.ttlMs;
    this.items.set(challenge, expiresAt);
    return { challenge, expiresAt };
  }
  consume(challenge: string): boolean {
    const expiresAt = this.items.get(challenge);
    if (expiresAt === undefined) return false;
    this.items.delete(challenge);
    return expiresAt >= Date.now();
  }
}

/**
 * Development bypass — used ONLY when APP_ATTEST_REQUIRED=false (never production). Accepts any
 * request and derives a best-effort identity from the provided keyId or a fixed dev id. A generic
 * bypass MUST NOT work in production (docs/05-architecture.md §16).
 */
export class DevBypassVerifier implements AttestationVerifier {
  private readonly store = new ChallengeStore();
  issueChallenge() {
    return this.store.issue();
  }
  async register(input: RegisterInput) {
    return { installId: input.keyId || 'dev-install' };
  }
  async verifyRequest(headers: AttestationHeaders) {
    return { identity: headers.keyId || 'dev-install' };
  }
}

/** Production App Attest verifier — real attestation + assertion verification (appAttestCrypto).
 *  register(): verify the CBOR attestation, the x5c chain to Apple's root, the nonce, appId/rpId hash,
 *  AAGUID, and keyId==credentialId; store the public key + signCount.
 *  verifyRequest(): consume a one-time challenge, verify the assertion signature over
 *  SHA256(authenticatorData || SHA256(challenge)), and that signCount strictly increases.
 *
 *  The key registry is injected so a deploy that enforces attestation can make it durable: the
 *  counter defends against replay only if it outlives the process (RULES.md §3). Challenges stay
 *  in-process on purpose — they live 5 minutes, and a restart costs at most one retried request. */
export class AppAttestVerifier implements AttestationVerifier {
  private readonly store = new ChallengeStore();

  constructor(
    private readonly appId: string,
    private readonly productionAAGUID: boolean = false,
    private readonly keys: AttestedKeyStore = new MemoryAttestedKeyStore(),
  ) {}

  issueChallenge() {
    return this.store.issue();
  }

  async register(input: RegisterInput): Promise<{ installId: string }> {
    if (!this.store.consume(input.challenge)) {
      throw new AttestationError('invalid or expired challenge');
    }
    if (!input.keyId || !input.attestationBase64) {
      throw new AttestationError('missing attestation');
    }
    try {
      const result = await verifyAttestation({
        attestation: Buffer.from(input.attestationBase64, 'base64'),
        challenge: input.challenge,
        keyId: input.keyId,
        appId: this.appId,
        requireProductionAAGUID: this.productionAAGUID,
      });
      this.keys.put(input.keyId, {
        publicKeyPem: result.publicKeyPem,
        signCount: result.signCount,
      });
      return { installId: input.keyId };
    } catch (err) {
      throw new AttestationError(err instanceof AppAttestError ? err.message : 'attestation failed');
    }
  }

  async verifyRequest(headers: AttestationHeaders): Promise<{ identity: string }> {
    if (!headers.keyId || !headers.assertionBase64 || !headers.challenge) {
      throw new AttestationError('missing assertion');
    }
    if (!this.store.consume(headers.challenge)) {
      throw new AttestationError('invalid or expired challenge');
    }
    const stored = this.keys.get(headers.keyId);
    if (!stored) throw new AttestationError('unknown key');
    try {
      const clientDataHash = createHash('sha256').update(headers.challenge).digest();
      const { signCount } = verifyAssertion({
        assertion: Buffer.from(headers.assertionBase64, 'base64'),
        clientDataHash,
        publicKeyPem: stored.publicKeyPem,
        previousSignCount: stored.signCount,
        appId: this.appId,
      });
      this.keys.updateSignCount(headers.keyId, signCount); // persist the monotonic counter
      return { identity: headers.keyId };
    } catch (err) {
      throw new AttestationError(err instanceof AppAttestError ? err.message : 'assertion failed');
    }
  }
}

/** Pick the verifier based on config. Production requires an App ID and a durable key store. */
export function makeVerifier(
  required: boolean,
  appId?: string,
  productionAAGUID = false,
  keys?: AttestedKeyStore,
): AttestationVerifier {
  if (!required) return new DevBypassVerifier();
  if (!appId) throw new Error('APP_ATTEST_APP_ID is required when APP_ATTEST_REQUIRED=true');
  return new AppAttestVerifier(appId, productionAAGUID, keys ?? new MemoryAttestedKeyStore());
}
