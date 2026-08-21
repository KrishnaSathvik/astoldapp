import styles from './FeatureList.module.css';

type Props = {
  items: readonly string[];
  /** `plain` is a quiet checked list; `rule` separates each line with a hairline. */
  variant?: 'plain' | 'rule';
};

export function FeatureList({ items, variant = 'plain' }: Props) {
  return (
    <ul className={`${styles.list} ${styles[variant]}`}>
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ul>
  );
}
