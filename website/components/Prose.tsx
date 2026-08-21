import type { ReactNode } from 'react';
import styles from './Prose.module.css';

/** The document voice: Privacy and Terms. Reading column, no marketing furniture. */
export function Prose({ children }: { children: ReactNode }) {
  return <div className={styles.prose}>{children}</div>;
}

export function ShortVersion({ children }: { children: ReactNode }) {
  return <div className={styles.short}>{children}</div>;
}

export function ContactBlock({ children }: { children: ReactNode }) {
  return <div className={styles.contact}>{children}</div>;
}
