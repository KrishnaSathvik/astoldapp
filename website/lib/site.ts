import type { Metadata } from 'next';

/**
 * `www` on purpose, and it must match the Vercel project's **primary** domain.
 *
 * Both hosts are attached; `www` is primary, so the bare apex 308-redirects to
 * it. Every absolute URL the site emits is built from this one constant —
 * canonical, `og:url`, `og:image`, sitemap — so when it named the apex, every
 * page was declaring a canonical that immediately redirected somewhere else.
 * If the primary is ever changed in Vercel, change it here in the same breath.
 */
export const SITE_URL = 'https://www.astold.app';

export const SITE_NAME = 'As Told';
export const TAGLINE = 'Write it. Say it. Keep it.';
export const PROMISE = 'Anything you want to put into words.';

/**
 * The header owns product discovery, so these links live in exactly one place.
 * The footer is utility/legal only and never repeats them.
 */
export const PRIMARY_NAV = [
  { href: '/#writing', label: 'Product' },
  { href: '/voice', label: 'Voice' },
  { href: '/languages', label: 'Languages' },
] as const;

export const UTILITY_NAV = [
  { href: '/privacy', label: 'Privacy' },
  { href: '/support', label: 'Support' },
  { href: '/terms', label: 'Terms' },
] as const;

/**
 * The listing is live (approved 2026-08-26), so every call to action on the
 * site is a real link. This is still the only place the store is named: the
 * CTA reads `APP_STORE_URL`, and the iOS Safari smart banner in `app/layout.tsx`
 * is built from `APP_STORE_ID`. The `| null` type is kept on purpose — the
 * `pending` CTA state is one edit away if the listing ever has to come down.
 */
export const APP_STORE_ID = '6804007726';
export const APP_STORE_URL: string | null =
  `https://apps.apple.com/us/app/as-told/id${APP_STORE_ID}`;

/**
 * Deliberately `null`, and not an oversight.
 *
 * A support contact for App Store Connect does exist. It is recorded once — in
 * `docs/08-positioning-marketing.md`, under "Outstanding" — and is not repeated
 * here, because it is a personal mailbox: setting it below would print it as
 * plain text on three public pages, where it would be scraped within days. App
 * Review needs a contact; the website does not need to publish one. The public
 * support surface on the listing is the `/support` URL.
 *
 * So `SupportContact` renders the self-service answer instead, which is true:
 * the FAQ and the app's own Writing help are where the answers are.
 *
 * When there is a real mailbox on the astold.app domain, set it here — a bare
 * address, no `mailto:` — and Support, Privacy, and Terms all become a real
 * contact line at once. Nothing else needs editing.
 */
export const SUPPORT_EMAIL: string | null = null;

type PageMetaInput = {
  title: string;
  description: string;
  path: string;
};

export function pageMetadata({ title, description, path }: PageMetaInput): Metadata {
  const url = `${SITE_URL}${path === '/' ? '/' : path}`;
  return {
    title,
    description,
    alternates: { canonical: url },
    openGraph: {
      type: 'website',
      siteName: SITE_NAME,
      url,
      title,
      description,
      images: [
        {
          url: `${SITE_URL}/og.png`,
          width: 1200,
          height: 630,
          alt: `${SITE_NAME} — ${PROMISE} ${TAGLINE}`,
        },
      ],
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description,
      images: [`${SITE_URL}/og.png`],
    },
  };
}
