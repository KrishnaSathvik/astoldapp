import styles from './Steps.module.css';

export function Steps({ items, center = false }: { items: readonly string[]; center?: boolean }) {
  return (
    <ol className={`${styles.steps} ${center ? styles.center : ''}`}>
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ol>
  );
}
