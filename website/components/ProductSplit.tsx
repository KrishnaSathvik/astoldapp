import type { ReactNode } from 'react';
import styles from './ProductSplit.module.css';

type Props = {
  eyebrow?: string;
  title: ReactNode;
  lede?: ReactNode;
  children?: ReactNode;
  media: ReactNode;
  /** Puts the media on the left. Alternate it down the page. */
  reverse?: boolean;
  /** Gives the media column the wider half — for a screenshot that carries the section. */
  mediaLed?: boolean;
};

export function ProductSplit({
  eyebrow,
  title,
  lede,
  children,
  media,
  reverse = false,
  mediaLed = false,
}: Props) {
  return (
    <div
      className={`reveal ${styles.split} ${reverse ? styles.reverse : ''} ${
        mediaLed ? styles.mediaLed : ''
      }`}
    >
      <div className={styles.copy}>
        {eyebrow ? <span className="eyebrow">{eyebrow}</span> : null}
        <h2>{title}</h2>
        {lede ? <p className={`lede ${styles.lede}`}>{lede}</p> : null}
        {children}
      </div>
      <div className={styles.media}>{media}</div>
    </div>
  );
}
