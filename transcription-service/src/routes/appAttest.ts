import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { AttestationError, type AttestationVerifier } from '../security/attestation.js';

const registerSchema = z.object({
  keyId: z.string().min(1),
  attestationBase64: z.string().min(1),
  challenge: z.string().min(1),
});

export async function appAttestRoutes(
  app: FastifyInstance,
  verifier: AttestationVerifier,
): Promise<void> {
  app.post('/v1/app-attest/challenge', async () => verifier.issueChallenge());

  app.post('/v1/app-attest/register', async (req, reply) => {
    const parsed = registerSchema.safeParse(req.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_request' });
    try {
      return await verifier.register(parsed.data);
    } catch (err) {
      if (err instanceof AttestationError) {
        return reply.code(401).send({ error: 'attestation_failed' });
      }
      throw err;
    }
  });
}
