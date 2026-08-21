import type { ReactNode } from 'react';
import styles from './FAQ.module.css';

export type FaqItem = {
  q: string;
  a: ReactNode;
};

type Props = {
  items: readonly FaqItem[];
  /**
   * The group this block answers for. The page is long enough now that an
   * undifferentiated list of eighteen questions is a wall; the headings are
   * what let someone with a paste question skip four sections of voice.
   */
  title?: string;
  /** Opens the first row. Exactly one block on a page may do this — the rows
      share a `name`, so a second one would only close the first. */
  openFirst?: boolean;
};

/** Native <details>, so the accordion works before any JavaScript loads. */
export function FAQ({ items, title, openFirst = false }: Props) {
  return (
    <section className={styles.group}>
      {title ? <h2 className={styles.groupTitle}>{title}</h2> : null}
      <div className={styles.faq}>
        {items.map(({ q, a }, index) => (
          <details key={q} name="faq" open={openFirst && index === 0}>
            <summary>
              {q}
              <span className={styles.chevron} aria-hidden="true" />
            </summary>
            <div className={styles.answer}>{a}</div>
          </details>
        ))}
      </div>
    </section>
  );
}
