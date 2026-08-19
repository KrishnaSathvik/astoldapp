import type { FastifyServerOptions } from 'fastify';

/**
 * Metadata-only logging. Logs MUST carry request id, route, status, latency, model, byte size, and a
 * coarse error category — and NEVER audio, transcript, note title/body, or search terms
 * (RULES.md §3, docs/05-architecture.md §22). We redact aggressively and never log request bodies.
 */
export function loggerOptions(
  nodeEnv: string,
  destination?: NodeJS.WritableStream,
): FastifyServerOptions['logger'] {
  // Silent under test unless a test explicitly asks for the output — the metadata-only guarantee is
  // worth asserting against real log records, and that only proves anything if the records come
  // through this exact configuration rather than a stand-in logger.
  if (nodeEnv === 'test' && destination === undefined) return false;
  return {
    level: process.env.LOG_LEVEL ?? 'info',
    ...(destination ? { stream: destination } : {}),
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
