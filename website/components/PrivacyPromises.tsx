import styles from './PrivacyPromises.module.css';

/**
 * Four promises as plain typography.
 *
 * These were four floating cards with icons and shadows, which turned the
 * quietest claim on the site into dashboard furniture. A promise about not
 * collecting anything should not arrive in a widget.
 */
const PROMISES = [
  ['No account', 'No sign-up, no email, no password.'],
  ['Notes stay local', 'Your library lives on your iPhone, not in a cloud copy.'],
  ['Optional Face ID', 'Covered in the app switcher until you unlock.'],
  ['No ads or analytics', 'No tracking, and no third-party SDK of any kind.'],
] as const;

export function PrivacyPromises() {
  return (
    <dl className={styles.promises}>
      {PROMISES.map(([term, detail]) => (
        <div key={term} className={styles.item}>
          <dt>{term}</dt>
          <dd>{detail}</dd>
        </div>
      ))}
    </dl>
  );
}
