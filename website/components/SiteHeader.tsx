'use client';

import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';
import { PRIMARY_NAV } from '@/lib/site';
import { AppStoreButton } from './AppStoreButton';
import styles from './SiteHeader.module.css';

/**
 * The wordmark, one link, and the CTA — one row at every width, on a phone
 * included. There is nothing here to hide behind a hamburger, and nothing that
 * needs a second row.
 *
 * The wordmark is Product; Privacy, Support and Terms are the footer's.
 */
export function SiteHeader() {
  const pathname = usePathname();
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <header className={`${styles.header} ${scrolled ? styles.scrolled : ''}`}>
      <div className={`wrap ${styles.bar}`}>
        <Link className={styles.brand} href="/" aria-label="As Told home">
          <Image src="/assets/mark-160.webp" alt="" width={28} height={28} priority />
          As Told
        </Link>

        <nav className={styles.links} aria-label="Primary">
          {PRIMARY_NAV.map(({ href, label }) => (
            <Link
              key={href}
              href={href}
              aria-current={pathname === href ? 'page' : undefined}
              className={pathname === href ? styles.current : undefined}
            >
              {label}
            </Link>
          ))}
        </nav>

        <div className={styles.cta}>
          <AppStoreButton size="compact" />
        </div>
      </div>
    </header>
  );
}
