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
            <li>English · తెలుగు · हिन्दी</li>
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
