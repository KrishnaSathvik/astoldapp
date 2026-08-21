import type { Metadata } from 'next';

export const SITE_URL = 'https://astold.app';

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
 * There is no App Store record yet, so every call to action renders as a
 * non-interactive "Coming to the App Store" state. When there is a real store
 * URL, set it here and every CTA on the site becomes a link at once.
 */
export const APP_STORE_URL: string | null = null;

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
