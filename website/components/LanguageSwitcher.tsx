'use client';

import { useRef, useState, type ReactNode } from 'react';
import styles from './LanguageSwitcher.module.css';

export type LanguageSample = {
  id: string;
  /** Chip text, e.g. "Telugu + English". */
  label: string;
  /** BCP-47 tag for the sentence as a whole. */
  lang: string;
  sentence: ReactNode;
  /** One product line. Not a linguistic gloss — the sentence proves itself. */
  caption: string;
};

/**
 * Five examples, one at a time.
 *
 * Every panel is rendered into the DOM and merely hidden, so the Telugu and
 * Hindi sentences — the substance of this page, and what it ranks for — are
 * present for crawlers rather than locked behind a click. The <noscript> block
 * reveals all five and drops the tab bar, so the page still works with no JS.
 */
export function LanguageSwitcher({ samples }: { samples: readonly LanguageSample[] }) {
  const [active, setActive] = useState(0);
  const tabs = useRef<Array<HTMLButtonElement | null>>([]);

  const move = (to: number) => {
    const next = (to + samples.length) % samples.length;
    setActive(next);
    tabs.current[next]?.focus();
  };

  return (
    <div className={styles.switcher}>
      <noscript>
        <style>{`.${styles.tablist}{display:none}.${styles.panel}[hidden]{display:block}`}</style>
      </noscript>

      <div className={styles.tablist} role="tablist" aria-label="Ways of speaking">
        {samples.map((sample, i) => (
          <button
            key={sample.id}
            ref={(el) => {
              tabs.current[i] = el;
            }}
            type="button"
            role="tab"
            id={`tab-${sample.id}`}
            aria-selected={i === active}
            aria-controls={`panel-${sample.id}`}
            tabIndex={i === active ? 0 : -1}
            className={`${styles.tab} ${i === active ? styles.tabActive : ''}`}
            onClick={() => setActive(i)}
            onKeyDown={(e) => {
              if (e.key === 'ArrowRight') { e.preventDefault(); move(active + 1); }
              if (e.key === 'ArrowLeft') { e.preventDefault(); move(active - 1); }
              if (e.key === 'Home') { e.preventDefault(); move(0); }
              if (e.key === 'End') { e.preventDefault(); move(samples.length - 1); }
            }}
          >
            {sample.label}
          </button>
        ))}
      </div>

      <div className={styles.stage}>
        {samples.map((sample, i) => (
          <div
            key={sample.id}
            role="tabpanel"
            id={`panel-${sample.id}`}
            aria-labelledby={`tab-${sample.id}`}
            tabIndex={0}
            className={styles.panel}
            /* `hidden`, not an inline display: an inline style outranks the
               media query that makes the visible panel a two-column grid, and
               `hidden` also drops the inactive panels out of the a11y tree. */
            hidden={i !== active}
          >
            <span className={styles.panelLabel}>{sample.label}</span>
            <p lang={sample.lang} className={styles.sentence}>
              {sample.sentence}
            </p>
            <p className={styles.caption}>{sample.caption}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
