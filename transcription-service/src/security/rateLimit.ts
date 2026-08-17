/**
 * Per-identity rate limiting. Because there is no user account, the primary key is the attested
 * install identity, with IP as a secondary signal (docs/05-architecture.md §17). Swap the in-memory
 * store for Redis in production.
 */
export interface RateLimiter {
  /** Returns true if the request is allowed; false if the identity is over the limit. */
  take(identity: string): boolean;
}

export class InMemoryRateLimiter implements RateLimiter {
  private readonly hits = new Map<string, number[]>();

  constructor(
    private readonly max: number,
    private readonly windowMs: number,
    private readonly now: () => number = Date.now,
  ) {}

  take(identity: string): boolean {
    const t = this.now();
    const cutoff = t - this.windowMs;
    const recent = (this.hits.get(identity) ?? []).filter((ts) => ts > cutoff);
    if (recent.length >= this.max) {
      this.hits.set(identity, recent);
      return false;
    }
    recent.push(t);
    this.hits.set(identity, recent);
    return true;
  }
}
