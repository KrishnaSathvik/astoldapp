import { describe, it, expect } from 'vitest';
import { loggerOptions } from '../src/observability/logger.js';

describe('logger metadata-only guarantee (RULES.md §3)', () => {
  it('disables logging entirely in test env', () => {
    expect(loggerOptions('test')).toBe(false);
  });

  it('request serializer keeps only method/url/id — never body or headers', () => {
    const opts = loggerOptions('production') as { serializers: Record<string, (v: unknown) => unknown> };
    const out = opts.serializers.req({
      method: 'POST',
      url: '/v1/transcriptions',
      id: 'req-1',
      body: { text: 'SECRET NOTE CONTENT' },
      headers: { authorization: 'Bearer secret', 'x-attest-assertion': 'abc' },
    }) as Record<string, unknown>;

    expect(out).toEqual({ method: 'POST', url: '/v1/transcriptions', id: 'req-1' });
    expect(JSON.stringify(out)).not.toContain('SECRET NOTE CONTENT');
    expect(JSON.stringify(out)).not.toContain('secret');
  });

  it('response serializer keeps only the status code', () => {
    const opts = loggerOptions('production') as { serializers: Record<string, (v: unknown) => unknown> };
    const out = opts.serializers.res({ statusCode: 200, text: 'transcript' }) as Record<string, unknown>;
    expect(out).toEqual({ statusCode: 200 });
  });
});
