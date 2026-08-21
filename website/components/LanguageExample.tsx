import type { ReactNode } from 'react';
import styles from './LanguageExample.module.css';

type Props = {
  label: string;
  /** BCP-47 tag for the sentence as a whole, so screen readers pick the voice. */
  lang: string;
  children: ReactNode;
};

/**
 * Just the sentence. No linguistic gloss underneath it — naming the grammar
 * ("English nouns carrying Telugu case endings") is true and nobody cares. The
 * specimen works when a reader recognises how they already talk.
 */
export function LanguageExample({ label, lang, children }: Props) {
  return (
    <div className={styles.specimen}>
      <span className={styles.label}>{label}</span>
      <p lang={lang} className={styles.line}>
        {children}
      </p>
    </div>
  );
}

/** An English run inside a Telugu or Hindi sentence. */
export function En({ children }: { children: ReactNode }) {
  return (
    <span lang="en" className={styles.en}>
      {children}
    </span>
  );
}

export function LanguageChips() {
  const chips = ['English', 'తెలుగు', 'हिन्दी', 'Telugu + English', 'Hindi + English'];
  return (
    <ul className={styles.chips}>
      {chips.map((chip) => (
        <li key={chip}>{chip}</li>
      ))}
    </ul>
  );
}
