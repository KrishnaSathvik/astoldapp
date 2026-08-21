import Image from 'next/image';
import Link from 'next/link';
import { PROMISE, UTILITY_NAV } from '@/lib/site';
import styles from './SiteFooter.module.css';

/**
 * Utility and legal only. Product discovery belongs to the header, and
 * repeating it here is what made the old footer feel like a sitemap.
 */
export function SiteFooter() {
  return (
    <footer className={styles.footer}>
      <div className={`wrap ${styles.inner}`}>
        <div>
          <Link className={styles.brand} href="/">
            <Image src="/assets/mark-160.webp" alt="" width={22} height={22} />
            As Told
          </Link>
          <p className={styles.promise}>{PROMISE}</p>
        </div>

        <nav className={styles.links} aria-label="Legal and support">
          {UTILITY_NAV.map(({ href, label }) => (
            <Link key={href} href={href}>
              {label}
            </Link>
          ))}
        </nav>
      </div>
      <div className={`wrap ${styles.copyright}`}>© 2026 As Told</div>
    </footer>
  );
}
