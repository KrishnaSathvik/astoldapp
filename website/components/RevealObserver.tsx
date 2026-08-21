'use client';

import { useEffect } from 'react';
import { usePathname } from 'next/navigation';

/**
 * One observer for the whole site: every element carrying `reveal` fades in as
 * it arrives. Keeping it here rather than in each component means the sections
 * stay server-rendered and the client bundle stays a few hundred bytes.
 */
export function RevealObserver() {
  const pathname = usePathname();

  useEffect(() => {
    const targets = Array.from(document.querySelectorAll<HTMLElement>('.reveal:not(.isIn)'));
    if (targets.length === 0) return;

    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduced || !('IntersectionObserver' in window)) {
      targets.forEach((el) => el.classList.add('isIn'));
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add('isIn');
          observer.unobserve(entry.target);
        });
      },
      { rootMargin: '0px 0px -6% 0px', threshold: 0.06 },
    );

    targets.forEach((el) => observer.observe(el));
    return () => observer.disconnect();
  }, [pathname]);

  return null;
}
