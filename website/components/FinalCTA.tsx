import Image from 'next/image';
import { TAGLINE } from '@/lib/site';
import { AppStoreButton } from './AppStoreButton';
import styles from './FinalCTA.module.css';

/**
 * One calm ending, once per page. Utility pages (Privacy, Support, Terms) do
 * not use it.
 */
export function FinalCTA({ title = "Whatever's on your mind." }: { title?: string }) {
  return (
    <section className={styles.final}>
      <div className={`wrap reveal ${styles.inner}`}>
        <Image
          className={styles.feather}
          src="/assets/mark-160.webp"
          alt=""
          width={64}
          height={64}
        />
        <h2>{title}</h2>
        <p className={styles.tagline}>{TAGLINE}</p>
        <AppStoreButton />
        <p className={styles.avail}>For iPhone.</p>
      </div>
    </section>
  );
}
