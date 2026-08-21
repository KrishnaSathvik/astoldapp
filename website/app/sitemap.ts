import type { MetadataRoute } from 'next';
import { SITE_URL } from '@/lib/site';

const LAST_MODIFIED = new Date('2026-08-21');

export default function sitemap(): MetadataRoute.Sitemap {
  const routes: Array<[string, number]> = [
    ['/', 1],
    ['/voice', 0.8],
    ['/languages', 0.8],
    ['/privacy', 0.5],
    ['/support', 0.5],
    ['/terms', 0.3],
  ];

  // `/` would give a trailing slash the canonical tags don't carry; keep the
  // two spellings identical so nothing looks like a second copy of the page.
  return routes.map(([path, priority]) => ({
    url: path === '/' ? SITE_URL : `${SITE_URL}${path}`,
    lastModified: LAST_MODIFIED,
    priority,
  }));
}
