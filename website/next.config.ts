import type { NextConfig } from 'next';

/**
 * Every URL the v8 static site published stays reachable. Vercel served that
 * site with `cleanUrls`, which 308'd `/support.html` to `/support`, so both
 * spellings are in the wild and both need a home here.
 */
const legacyRedirects = [
  ['/index.html', '/'],
  ['/voice-notes', '/voice'],
  ['/voice-notes.html', '/voice'],
  ['/multilingual', '/languages'],
  ['/multilingual.html', '/languages'],
  // `/private-notes` is retired as a page; its subject is privacy.
  ['/private-notes', '/privacy'],
  ['/private-notes.html', '/privacy'],
  ['/privacy.html', '/privacy'],
  ['/support.html', '/support'],
] as const;

const securityHeaders = [
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
];

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  trailingSlash: false,

  async redirects() {
    return legacyRedirects.map(([source, destination]) => ({
      source,
      destination,
      permanent: true,
    }));
  },

  async headers() {
    return [
      { source: '/:path*', headers: securityHeaders },
      {
        source: '/assets/:path*',
        headers: [{ key: 'Cache-Control', value: 'public, max-age=604800, immutable' }],
      },
    ];
  },
};

export default nextConfig;
