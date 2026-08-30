import Image from 'next/image';
import styles from './PhoneShot.module.css';

/**
 * Every capture comes out of the simulator at this size — iPhone 17 Pro, 3×,
 * unscaled. The library used to be downscaled to 720px before it reached the
 * site, which is below the 1068 device-pixels an `lg` device asks for on a 3×
 * display; the captures are now kept at their native resolution and Next's
 * image pipeline does any reduction.
 */
const SHOT_WIDTH = 1206;
const SHOT_HEIGHT = 2622;

type Props = {
  src: string;
  alt: string;
  /** Rendered width of the device, in px, at the widest breakpoint. */
  size?: 'sm' | 'md' | 'lg' | 'xl';
  priority?: boolean;
};

/**
 * A screenshot is evidence, so it is never cropped, masked, faded, or overlapped
 * by anything else. If a device makes a section too tall, the fix is a smaller
 * `size` or a fuller copy column — never hiding part of the app.
 */
export function PhoneShot({ src, alt, size = 'md', priority = false }: Props) {
  return (
    <div className={`${styles.phone} ${styles[size]}`}>
      <Image
        src={src}
        alt={alt}
        width={SHOT_WIDTH}
        height={SHOT_HEIGHT}
        priority={priority}
        sizes="(max-width: 820px) 92vw, 510px"
        className={styles.shot}
      />
    </div>
  );
}

type PairProps = {
  children: React.ReactNode;
  /**
   * Steps the second device down. It never moves sideways into the first —
   * overlapping two captures hides real UI (it buried the calendar's back
   * button and its whole Sunday column).
   */
  stagger?: boolean;
  /**
   * Makes the devices share the row, shrinking to fit rather than wrapping.
   * Inside a column narrower than two devices, the default wrap stacks them
   * into a 1200px tower and leaves the neighbouring column empty. Below 700px
   * they stack anyway — two phones on a phone screen are too small to read.
   */
  fit?: boolean;
};

export function PhonePair({ children, stagger = false, fit = false }: PairProps) {
  return (
    <div className={`${styles.pair} ${stagger ? styles.stagger : ''} ${fit ? styles.fit : ''}`}>
      {children}
    </div>
  );
}

type FigureProps = {
  src: string;
  alt: string;
  caption: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
};

export function PhoneFigure({ src, alt, caption, size = 'md' }: FigureProps) {
  return (
    <figure className={`${styles.figure} ${styles[size]}`}>
      <PhoneShot src={src} alt={alt} size={size} />
      <figcaption>{caption}</figcaption>
    </figure>
  );
}
