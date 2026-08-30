import type { ReactNode } from 'react';
import { AppStoreButton } from './AppStoreButton';
import { PhoneShot } from './PhoneShot';
import styles from './Hero.module.css';

type Props = {
  eyebrow?: string;
  title: ReactNode;
  lede: ReactNode;
  shot: { src: string; alt: string };
};

export function Hero({ eyebrow, title, lede, shot }: Props) {
  return (
    <section className={styles.hero}>
      <div className={`wrap ${styles.grid}`}>
        <div className={styles.copy}>
          {eyebrow ? <span className="eyebrow">{eyebrow}</span> : null}
          <h1>{title}</h1>
          <p className={`lede ${styles.lede}`}>{lede}</p>
          <div className={styles.cta}>
            <AppStoreButton />
          </div>
          <ul className={styles.proof} aria-label="As Told at a glance">
            <li>No account</li>
            {/* This read "English · తెలుగు · हिन्दी" until 2026-08-28, which put a
                supported-languages list in the first 400px of the site and made
                As Told read as a three-language app. The capability is the
                claim; the tested groups are a footnote further down
                (`RULES.md` §7, "Language claims"). */}
            <li>Multilingual voice</li>
            <li>Face ID optional</li>
          </ul>
        </div>

        <div className={styles.visual}>
          <PhoneShot src={shot.src} alt={shot.alt} size="xl" priority />
        </div>
      </div>

      <div className={`wrap ${styles.verbs}`}>
        <span>Write it.</span>
        <span>Say it.</span>
        <span>Keep it.</span>
      </div>
    </section>
  );
}
