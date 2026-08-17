import { randomUUID } from 'node:crypto';

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

/**
 * Production App Attest verifier — STUB. The structure (challenge issue/consume, key registration,
 * per-request assertion) is here; the cryptographic verification against Apple's App Attest root is
 * intentionally left as a documented integration point.
 *
 * To complete (docs/06-tech-stack.md §11, Apple DeviceCheck docs):
 *  1. register(): decode the CBOR attestation, verify the x5c cert chain to Apple's App Attest root,
 *     confirm the nonce = SHA256(authenticatorData || SHA256(challenge)), the appId/rpId hash, the
 *     AAGUID, then persist the public key + a signCount keyed by keyId.
 *  2. verifyRequest(): verify the assertion signature over SHA256(authenticatorData || clientDataHash)
 *     with the stored public key, and that signCount strictly increases.
 */
export class AppAttestVerifier implements AttestationVerifier {
  private readonly store = new ChallengeStore();
  private readonly keys = new Map<string, { publicKey: string; signCount: number }>();

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
    // TODO(prod): verify CBOR attestation + Apple cert chain before trusting the key. See class docs.
    throw new AttestationError('App Attest verification not configured');
  }

  async verifyRequest(headers: AttestationHeaders): Promise<{ identity: string }> {
    if (!headers.keyId || !headers.assertionBase64) {
      throw new AttestationError('missing assertion');
    }
    const stored = this.keys.get(headers.keyId);
    if (!stored) throw new AttestationError('unknown key');
    // TODO(prod): verify assertion signature + monotonic signCount. See class docs.
    throw new AttestationError('App Attest verification not configured');
  }
}

/** Pick the verifier based on config. */
export function makeVerifier(required: boolean): AttestationVerifier {
  return required ? new AppAttestVerifier() : new DevBypassVerifier();
}
