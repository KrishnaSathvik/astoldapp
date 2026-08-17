import type { FastifyServerOptions } from 'fastify';

/**
 * Metadata-only logging. Logs MUST carry request id, route, status, latency, model, byte size, and a
 * coarse error category — and NEVER audio, transcript, note title/body, or search terms
 * (RULES.md §3, docs/05-architecture.md §22). We redact aggressively and never log request bodies.
 */
export function loggerOptions(nodeEnv: string): FastifyServerOptions['logger'] {
  if (nodeEnv === 'test') return false;
  return {
    level: process.env.LOG_LEVEL ?? 'info',
    // Never serialize bodies; only safe request/response metadata.
    serializers: {
      req(req) {
        return { method: req.method, url: req.url, id: req.id };
      },
      res(res) {
        return { statusCode: res.statusCode };
      },
    },
    redact: {
      paths: ['req.headers.authorization', 'req.headers["x-attest-assertion"]'],
      remove: true,
    },
  };
}
