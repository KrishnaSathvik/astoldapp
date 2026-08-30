import Link from 'next/link';
import { FinalCTA } from '@/components/FinalCTA';
import { PageHero } from '@/components/PageHero';
import { Section, SectionIntro } from '@/components/Section';
import { pageMetadata } from '@/lib/site';
import styles from './page.module.css';

export const metadata = pageMetadata({
  title: 'Multilingual Voice Notes for iPhone',
  description:
    'Speak naturally across languages without choosing one first. As Told is designed for multilingual voice notes and natural code-switching without forced translation.',
  path: '/languages',
});

/**
 * A search landing page, and nothing more.
 *
 * It used to open with five chips — Telugu · Hindi · Telugu + English · Hindi +
 * English · English — over a tabbed switcher of Telugu and Hindi specimens, then
 * a Hindi closing example. Every one of those is real, and together they told a
 * visitor that As Told is a three-language app. They are the groups whose quality
 * is *measured* before a release, which is release evidence, not a product
 * boundary (`RULES.md` §7, "Language claims"), and they are now named in exactly
 * one place: the Support answer for "Which languages can I speak?".
 *
 * Cut again on 2026-08-29, from four sections and a device to two and none. A
 * page nothing links to does not need to be a second marketing site, and the
 * device it carried was a note in a particular script — the exact visual this
 * page was rebuilt to stop showing. It exists so that someone searching for
 * multilingual voice notes finds As Told; the product story is `/` and `/voice`.
 *
 * `/multilingual` still 308s here (`next.config.ts`), and the route stays in the
 * sitemap — but it is out of the primary navigation and out of the footer, and
 * neither `/` nor `/voice` links to it, because how voice treats languages is a
 * property of voice, not a fourth thing the product is.
 */
export default function LanguagesPage() {
  return (
    <>
      <PageHero
        eyebrow="Multilingual voice notes"
        title="Multilingual voice notes, without the language picker."
        lede="Start speaking first. As Told is built for voice notes that don't always stay in one language — there is nothing to choose before you record, and nothing you said is translated into a different language afterwards."
      />

      <Section flush>
        <div className={`reveal ${styles.principles}`}>
          <span>No language picker</span>
          <span>Switch naturally</span>
          <span>No forced translation</span>
        </div>
      </Section>

      <Section tone="warm">
        <SectionIntro
          title="Accuracy isn't identical everywhere."
          lede="Speech recognition varies. How well it does depends on the language, the accent, the room, the microphone, and how much the languages are mixed — so it is worth saying plainly that this is a capability, not a guarantee. Multilingual and mixed-language voice is tested before every release."
          wide
        >
          <p className={styles.note}>
            <Link className="textlink" href="/voice">
              How voice works →
            </Link>
          </p>
        </SectionIntro>
      </Section>

      <FinalCTA title="Say it however it comes." />
    </>
  );
}
