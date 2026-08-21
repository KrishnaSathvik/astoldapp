'use client';

import { useEffect, useState, type ReactNode } from 'react';
import styles from './DocLayout.module.css';

export type TocItem = { id: string; label: string };

type Props = {
  eyebrow?: string;
  title: ReactNode;
  lede?: ReactNode;
  /** Utility pages carry a "Last updated" line. */
  updated?: string;
  /**
   * Quiet anchor navigation for a long document. Desktop only — below 1060px it
   * disappears and the page is one column. A privacy policy is a wall of text;
   * a small list of where you are makes it scannable without turning the page
   * into an app with a sidebar.
   */
  toc?: readonly TocItem[];
  children: ReactNode;
};

/**
 * Privacy and Terms. A document, centred, in the reading column — not a
 * marketing composition with a narrow bar of text stranded on the left of a
 * 1440px screen.
 */
export function DocLayout({ eyebrow, title, lede, updated, toc, children }: Props) {
  const active = useActiveHeading(toc);

  return (
    <div className={`${styles.doc} ${toc ? styles.withToc : ''}`}>
      {toc ? (
        <nav className={styles.toc} aria-label="On this page">
          <p className={styles.tocTitle}>On this page</p>
          <ul>
            {toc.map(({ id, label }) => (
              <li key={id}>
                <a
                  href={`#${id}`}
                  className={active === id ? styles.tocCurrent : undefined}
                  aria-current={active === id ? 'true' : undefined}
                >
                  {label}
                </a>
              </li>
            ))}
          </ul>
        </nav>
      ) : null}

      <div className={styles.body}>
        <header className={styles.head}>
          {eyebrow ? <span className="eyebrow">{eyebrow}</span> : null}
          <h1>{title}</h1>
          {lede ? <p className={`lede ${styles.lede}`}>{lede}</p> : null}
          {updated ? <p className={styles.updated}>Last updated · {updated}</p> : null}
        </header>
        {children}
      </div>
    </div>
  );
}

/** Whichever heading was last crossed on the way down. */
function useActiveHeading(toc?: readonly TocItem[]) {
  const [active, setActive] = useState<string | null>(null);

  useEffect(() => {
    if (!toc?.length) return;
    const targets = toc
      .map(({ id }) => document.getElementById(id))
      .filter((el): el is HTMLElement => Boolean(el));
    if (!targets.length) return;

    const update = () => {
      // The header covers the top of the viewport, so "current" is measured
      // from just below it rather than from y = 0.
      const line = 140;
      let current = targets[0].id;
      for (const el of targets) {
        if (el.getBoundingClientRect().top <= line) current = el.id;
      }
      setActive(current);
    };

    update();
    window.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
    return () => {
      window.removeEventListener('scroll', update);
      window.removeEventListener('resize', update);
    };
  }, [toc]);

  return active;
}
