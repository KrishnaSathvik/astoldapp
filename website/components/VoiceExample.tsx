import type { ReactNode } from 'react';
import styles from './VoiceExample.module.css';

type Props = {
  /** What was spoken, without quotation marks — the component adds them. */
  said: string;
  /**
   * Stacks said-above-result with a downward arrow. For a single example living
   * in one half of a split, where three columns would shred the sentence.
   */
  stacked?: boolean;
  /** What the note ends up holding. */
  children: ReactNode;
};

export function VoiceExample({ said, stacked = false, children }: Props) {
  return (
    <div className={`${styles.example} ${stacked ? styles.stacked : ''}`}>
      <div className={styles.said}>
        <span className={styles.tag}>You say</span>
        <p>&ldquo;{said}&rdquo;</p>
      </div>
      <span className={styles.arrow} aria-hidden="true" />
      <div className={styles.got}>
        <span className={styles.tag}>Your note</span>
        <div className={styles.result}>{children}</div>
      </div>
    </div>
  );
}

export function ExampleGrid({ children }: { children: ReactNode }) {
  return <div className={styles.grid}>{children}</div>;
}

/* --- Result primitives, styled the way the app renders them ------------- */

export function ResultHeading({ children }: { children: ReactNode }) {
  return <p className={styles.rHeading}>{children}</p>;
}

export function ResultChecklist({ items }: { items: readonly string[] }) {
  return (
    <ul className={styles.rChecks}>
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ul>
  );
}

export function ResultBullets({ items }: { items: readonly string[] }) {
  return (
    <ul className={styles.rBullets}>
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ul>
  );
}

export function ResultText({ children }: { children: ReactNode }) {
  return <p className={styles.rText}>{children}</p>;
}
