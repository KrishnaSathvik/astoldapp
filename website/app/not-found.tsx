import Link from 'next/link';
import { PageHero } from '@/components/PageHero';
import { Section } from '@/components/Section';

export const metadata = { title: 'Page not found' };

export default function NotFound() {
  return (
    <>
      <PageHero
        eyebrow="404"
        title="That page isn't here."
        lede="The link may be old, or the page may have moved."
      />
      <Section tight>
        <Link className="textlink" href="/">
          Back to As Told →
        </Link>
      </Section>
    </>
  );
}
