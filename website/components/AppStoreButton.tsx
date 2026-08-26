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
 * As Told is **on** the App Store, so this is simply a link to it. The
 * pre-launch "Coming to the App Store" state is gone rather than switched off:
 * `APP_STORE_URL` is a constant in `lib/site.ts`, not a maybe, and a shipped
 * app has no use for a state that says it hasn't shipped. Only the official
 * Apple-supplied badge asset may replace this text; nothing else may.
 */
export function AppStoreButton({ size = 'full' }: Props) {
  return (
    <a
      className={`${styles.btn} ${size === 'compact' ? styles.compact : ''}`}
      href={APP_STORE_URL}
    >
      Get As Told
    </a>
  );
}
