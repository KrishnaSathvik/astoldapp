import { APP_STORE_URL } from '@/lib/site';
import styles from './AppStoreButton.module.css';

type Props = {
  /** `compact` is the header CTA; `full` is the one inside a section. */
  size?: 'compact' | 'full';
};

/**
 * The call to action, and deliberately **not** an App Store badge.
 *
 * This used to draw Apple's logo from a hand-copied SVG path next to the words
 * "Coming to the App Store", which is a counterfeit of a system control: Apple's
 * mark is Apple's, the badge has an official asset with its own layout rules,
 * and a homemade one reads as a fake the moment it sits next to a real one. So
 * the button is typographic — the site's own accent, the site's own type.
 *
 * There is no App Store record yet, so it renders as a non-interactive status
 * rather than a button that does nothing when tapped. It becomes a real link the
 * moment `APP_STORE_URL` is set, in one place, for the whole site. When that
 * happens the official Apple-supplied badge may replace this; nothing else may.
 */
export function AppStoreButton({ size = 'full' }: Props) {
  const className = `${styles.btn} ${size === 'compact' ? styles.compact : ''}`;

  if (APP_STORE_URL) {
    return (
      <a className={className} href={APP_STORE_URL}>
        Get As Told
      </a>
    );
  }

  return (
    <span className={`${className} ${styles.pending}`}>
      {size === 'compact' ? 'Get As Told' : 'Coming to the App Store'}
    </span>
  );
}
