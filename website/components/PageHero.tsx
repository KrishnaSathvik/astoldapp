import type { ReactNode } from 'react';
import styles from './PageHero.module.css';

/** The three site widths. A page picks one; it never invents its own. */
const WIDTH_CLASS = {
  shell: 'wrap',
  feature: 'wrapFeature',
  faq: 'wrapFaq',
  read: 'wrapRead',
} as const;

type Props = {
  eyebrow?: string;
  title: ReactNode;
  lede?: ReactNode;
  /** Utility pages carry a "Last updated" line; product pages don't. */
  updated?: string;
  /** Centres the copy — for a hero whose payload underneath is centred too. */
  align?: 'start' | 'center';
  width?: keyof typeof WIDTH_CLASS;
  children?: ReactNode;
};

export function PageHero({
  eyebrow,
  title,
  lede,
  updated,
  align = 'start',
  width = 'feature',
  children,
}: Props) {
  return (
    <section className={styles.hero}>
      <div className={WIDTH_CLASS[width]}>
        <div className={`${styles.copy} ${align === 'center' ? styles.center : ''}`}>
          {eyebrow ? <span className="eyebrow">{eyebrow}</span> : null}
          <h1>{title}</h1>
          {lede ? <p className={`lede ${styles.lede}`}>{lede}</p> : null}
          {updated ? <p className={styles.updated}>Last updated · {updated}</p> : null}
        </div>
        {children}
      </div>
    </section>
  );
}
