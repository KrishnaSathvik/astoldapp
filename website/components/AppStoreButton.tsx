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
 * The listing is live, so this is a real link to it — one `APP_STORE_URL`, set
 * in `lib/site.ts`, feeds every CTA on the site. The `pending` branch below is
 * kept because it is the honest state if that constant is ever `null` again;
 * it is not dead weight, it is the switch. Only the official Apple-supplied
 * badge asset may replace this text; nothing else may.
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
