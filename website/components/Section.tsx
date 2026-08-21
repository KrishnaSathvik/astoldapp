import type { ReactNode } from 'react';
import styles from './Section.module.css';

/** The three site widths. A section picks one; it never invents its own. */
const WIDTH_CLASS = {
  shell: 'wrap',
  feature: 'wrapFeature',
  faq: 'wrapFaq',
  read: 'wrapRead',
} as const;

type SectionProps = {
  id?: string;
  /** Background band. Alternating tone is what gives the page its rhythm. */
  tone?: 'plain' | 'warm' | 'deep';
  /** Which of the locked widths the content sits in. */
  width?: keyof typeof WIDTH_CLASS;
  tight?: boolean;
  /** Drops the top padding — for a section sitting directly under a page hero. */
  flush?: boolean;
  children: ReactNode;
};

export function Section({
  id,
  tone = 'plain',
  width = 'feature',
  tight = false,
  flush = false,
  children,
}: SectionProps) {
  return (
    <section
      id={id}
      className={`${styles.section} ${styles[tone]} ${tight ? styles.tight : ''} ${
        flush ? styles.flush : ''
      }`}
    >
      <div className={WIDTH_CLASS[width]}>{children}</div>
    </section>
  );
}

type IntroProps = {
  eyebrow?: string;
  title: ReactNode;
  lede?: ReactNode;
  align?: 'start' | 'center';
  /** Headline-only sections read better without the reading column cap. */
  wide?: boolean;
  children?: ReactNode;
};

export function SectionIntro({
  eyebrow,
  title,
  lede,
  align = 'start',
  wide = false,
  children,
}: IntroProps) {
  return (
    <div
      className={`reveal ${styles.intro} ${align === 'center' ? styles.center : ''} ${
        wide ? styles.wide : ''
      }`}
    >
      {eyebrow ? <span className="eyebrow">{eyebrow}</span> : null}
      <h2>{title}</h2>
      {lede ? <p className={`lede ${styles.introLede}`}>{lede}</p> : null}
      {children}
    </div>
  );
}
