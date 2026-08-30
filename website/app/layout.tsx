import type { Metadata, Viewport } from 'next';
import { RevealObserver } from '@/components/RevealObserver';
import { SiteFooter } from '@/components/SiteFooter';
import { SiteHeader } from '@/components/SiteHeader';
import { APP_STORE_ID, PROMISE, SITE_NAME, SITE_URL, TAGLINE } from '@/lib/site';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: 'As Told — Private Notes, Voice & Writing for iPhone',
    template: '%s · As Told',
  },
  description:
    'A private writing space for iPhone. Write it or say it — multilingual voice transcription, headings, lists, tables and code — and keep it on your device.',
  applicationName: SITE_NAME,
  /* Renders <meta name="apple-itunes-app">, which is the Safari smart banner on
     iOS — the one place a visitor already holding the right device can install
     without reading a word. Same listing id as every CTA. */
  itunes: { appId: APP_STORE_ID },
  manifest: '/site.webmanifest',
  icons: {
    icon: [
      { url: '/favicon.ico', sizes: 'any' },
      { url: '/favicon-32x32.png', sizes: '32x32', type: 'image/png' },
      { url: '/favicon-16x16.png', sizes: '16x16', type: 'image/png' },
    ],
    apple: '/apple-touch-icon.png',
  },
  openGraph: {
    type: 'website',
    siteName: SITE_NAME,
    images: [
      {
        url: '/og.png',
        width: 1200,
        height: 630,
        alt: `${SITE_NAME} — ${PROMISE} ${TAGLINE}`,
      },
    ],
  },
  twitter: { card: 'summary_large_image', images: ['/og.png'] },
};

export const viewport: Viewport = {
  themeColor: '#F8F7F3',
  colorScheme: 'light',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    /* `js` is rendered here rather than added by an inline script: mutating
       <html> before React hydrates makes the server and client trees disagree,
       which threw a hydration error on every page. The <noscript> below undoes
       it when there is no JavaScript to run the reveal. */
    <html lang="en" className="js">
      <body>
        <noscript>
          <style>{'.js .reveal{opacity:1!important;transform:none!important}'}</style>
        </noscript>
        <a className="skipLink" href="#main">
          Skip to content
        </a>
        <SiteHeader />
        <main id="main">{children}</main>
        <SiteFooter />
        <RevealObserver />
      </body>
    </html>
  );
}
