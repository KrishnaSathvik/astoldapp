'use client';

import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';
import { PRIMARY_NAV } from '@/lib/site';
import { AppStoreButton } from './AppStoreButton';
import styles from './SiteHeader.module.css';

/**
 * Three links and a CTA. That is not enough navigation to justify a hamburger,
 * a scrim, and a slide-over sheet — so on a phone the header simply becomes two
 * rows and keeps everything visible. Nothing here is ever hidden behind a tap.
 *
 * Product discovery only; Privacy / Support / Terms live in the footer.
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
