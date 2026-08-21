import styles from './FidelityBoundary.module.css';

/**
 * The verbatim contract in one comparison: punctuation is added, words are not
 * changed, and a tidier rewrite is refused outright.
 */
export function FidelityBoundary() {
  return (
    <div className={styles.boundary}>
      <div className={styles.row}>
        <span className={styles.tag}>You said</span>
        <p>
          Actually I don&rsquo;t know maybe we can go Saturday but if Ravi is coming then Sunday
          is probably better what do you think
        </p>
      </div>
      <div className={`${styles.row} ${styles.kept}`}>
        <span className={styles.tag}>You get</span>
        <p>
          Actually, I don&rsquo;t know. Maybe we can go Saturday, but if Ravi is coming, then
          Sunday is probably better. What do you think?
        </p>
      </div>
      <div className={`${styles.row} ${styles.refused}`}>
        <span className={styles.tag}>Never</span>
        <p>Ravi and I should probably go on Sunday instead of Saturday.</p>
      </div>
    </div>
  );
}

export function FidelityPromises() {
  const promises = [
    'No grammar correction',
    'No paraphrasing',
    'No summarising',
    'No translation',
  ];
  return (
    <ul className={styles.promises}>
      {promises.map((promise) => (
        <li key={promise}>{promise}</li>
      ))}
    </ul>
  );
}
