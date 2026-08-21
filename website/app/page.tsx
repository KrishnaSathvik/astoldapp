import Link from 'next/link';
import { FeatureList } from '@/components/FeatureList';
import { FinalCTA } from '@/components/FinalCTA';
import { Hero } from '@/components/Hero';
import { En, LanguageExample } from '@/components/LanguageExample';
import { PhoneFigure, PhonePair, PhoneShot } from '@/components/PhoneShot';
import { PrivacyPromises } from '@/components/PrivacyPromises';
import { ProductSplit } from '@/components/ProductSplit';
import { Section, SectionIntro } from '@/components/Section';
import { Steps } from '@/components/Steps';
import { ResultChecklist, VoiceExample } from '@/components/VoiceExample';
import { pageMetadata } from '@/lib/site';
import styles from './page.module.css';

export const metadata = pageMetadata({
  title: 'As Told — Private Notes, Voice & Writing for iPhone',
  description:
    'A private writing space for iPhone. Write it or speak it — in English, Telugu or Hindi — shape it with headings and lists, and keep it on your device.',
  path: '/',
});

/** The six structures, named. The shapes themselves are in the screenshots. */
const STRUCTURES = [
  'Paragraph',
  'Heading',
  'Subheading',
  'Bulleted list',
  'Numbered list',
  'Checklist',
];

/**
 * What survives a paste, and it is exactly the list of structures the editor
 * already has — nothing here is a formatting capability paste adds.
 */
const PASTE_KEEPS = [
  'Headings and subheadings',
  'Paragraph breaks',
  'Bulleted and numbered lists',
  'Checklists you can still tick',
  'Tables, as a table',
  'Telugu, Hindi and English together',
];

/**
 * Eight sections, and no more.
 *
 *   1  Hero
 *   2  Write
 *   3  Structure — the writing toolbar
 *   4  Paste — including how a table reads
 *   5  Voice (including spoken structure)
 *   6  Multilingual
 *   7  Organization + Privacy
 *   8  Light / Dark  →  Final CTA
 *
 * The composition changes down the page on purpose: split, split reversed,
 * intro-over-media, split reversed, specimens, two-up, centred pair. A section
 * that looks like the section above it stops being read.
 */
export default function HomePage() {
  return (
    <>
      {/* 1 — Hero */}
      <Hero
        eyebrow="Private writing for iPhone"
        title="Anything you want to put into words."
        lede="A quiet place for thoughts, notes, drafts, lists and the things you want to remember. Write it or say it — As Told keeps it."
        shot={{
          src: '/assets/shots/home-light.webp',
          alt: 'The As Told home screen: notes grouped under Today, Yesterday, and August 19, with a search field pinned at the bottom.',
        }}
      />

      {/* 2 — Write. Start blank; the note is the whole interface. */}
      <Section id="writing" tone="warm">
        <ProductSplit
          eyebrow="Write"
          title="Just start writing."
          lede="Thoughts, notes, drafts, plans, lists — one page, without choosing what kind of note you're making first."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/structure-light.webp"
              alt="A note in As Told called Weekend in Seattle: a heading, a line of prose, then a checklist with one item ticked, a numbered list of Saturday plans, and a bulleted packing list."
            />
          }
        >
          <FeatureList
            variant="rule"
            items={['No folders to set up', 'No note types to choose', 'No Save button']}
          />
          <p className={styles.turnBody}>
            Notes are kept the moment you write them and land in your timeline by the day you wrote
            them. Nothing to file, nothing to name.
          </p>
        </ProductSplit>
      </Section>

      {/* 3 — Structure. The writing toolbar, described as what it actually is. */}
      <Section id="structure">
        <ProductSplit
          reverse
          eyebrow="Structure"
          title="Shape it while you write."
          lede="A writing toolbar sits just above the keyboard — As Told's own, not a row bolted onto Apple's. Aa holds Heading and Subheading; then a bullet, a number, and a checkbox, one tap each."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/toolbar-light.webp"
              alt="The As Told writing toolbar floating above the iPhone keyboard: an Aa style button, then bulleted list, numbered list and checklist buttons with the bulleted one highlighted, a divider, and a microphone."
            />
          }
        >
          <ul className={styles.chips}>
            {STRUCTURES.map((name) => (
              <li key={name}>{name}</li>
            ))}
          </ul>

          <div className={styles.turn}>
            <h3 className={styles.turnTitle}>Or type it. Or say it.</h3>
            <p className={styles.turnBody}>
              Start a line with the usual marker and it becomes a list. Return carries the list on,
              Return on an empty item ends it, and a spoken command does the same thing hands-free.
              Three ways in, one set of shapes.
            </p>
          </div>

          <p className={styles.aside}>
            No bold, no italic, no colours, no font menu. Six structures is the whole vocabulary —
            which is why a note never turns into a document you have to maintain.
          </p>
        </ProductSplit>
      </Section>

      {/* 4 — Paste. A capability people arrive with, and the boundary on it. */}
      <Section tone="warm">
        {/* Title and lede side by side rather than stacked in a reading column.
            Every other section on the page opens left-aligned over empty right
            half; this one uses its width, which is what stops the page reading
            as one template repeated eight times. */}
        <div className={`reveal ${styles.pasteHead}`}>
          <div>
            <span className="eyebrow">Paste</span>
            <h2>Paste it without turning it into a wall of text.</h2>
          </div>
          <p className="lede">
            Copy a plan out of a chat, a table out of a browser, a list out of a document. If the
            clipboard states what those lines were, As Told keeps every shape it has a place for.
          </p>
        </div>

        <div className={`reveal ${styles.pasteGrid}`}>
          <PhoneShot
            size="lg"
            src="/assets/shots/table-light.webp"
            alt="A pasted note in As Told called Trip budget: a Fixed costs subheading above a two-column table of Item and Estimate rows — Hotel $1,400, Rental car $650, Boat tour $229, Flights $980 — then a Still to price checklist."
          />

          <div className={styles.pasteCopy}>
            <span className="eyebrow">What comes across</span>
            <FeatureList variant="rule" items={PASTE_KEEPS} />

            <div className={styles.turn}>
              <h3 className={styles.turnTitle}>And what doesn&rsquo;t.</h3>
              <p className={styles.turnBody}>
                Bold, italic, colours, fonts and page layout have nowhere to go in a note, so they
                simplify to text. Plain text is pasted exactly as it arrived — As Told never reads
                shape into lines the clipboard didn&rsquo;t claim any.
              </p>
              <p className={styles.turnBody}>
                <strong>Your words are not rewritten because you pasted them.</strong> This is
                clipboard compatibility, not an integration: As Told doesn&rsquo;t connect to any
                other app or account, and never sees more than what you copied.
              </p>
            </div>
          </div>
        </div>
      </Section>

      {/* 5 — Voice, including spoken structure. Two sections said one thing twice. */}
      <Section tone="deep">
        <ProductSplit
          reverse
          eyebrow="Voice"
          title="Or just say it."
          lede="Put the cursor where the thought belongs, tap the mic on the same toolbar, and speak normally. Your words return to that spot, as ordinary text you can keep editing."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/recording-light.webp"
              alt="The As Told recording panel over the note being written: a live level meter, an elapsed time of 00:01, and Cancel and Done controls."
            />
          }
        >
          <Steps items={['Tap', 'Speak', 'Keep writing']} />

          <div className={styles.spoken}>
            <span className="eyebrow">Spoken structure</span>
            <p className={styles.spokenLede}>
              A thought can arrive already organised. Say a clear, standalone command and the next
              thing you say takes that shape.
            </p>
            <VoiceExample stacked said="Checklist. Book hotel. Next item. Rent car.">
              <ResultChecklist items={['Book hotel', 'Rent car']} />
            </VoiceExample>
            <p className={styles.spokenNote}>
              Only an isolated command counts — ordinary speech that merely mentions one is left
              alone.
            </p>
          </div>

          <Link className={`textlink ${styles.afterLink}`} href="/voice">
            Explore voice →
          </Link>
        </ProductSplit>
      </Section>

      {/* 6 — Multilingual. Two specimens, then the same thing inside the app. */}
      <Section>
        <div className={`reveal ${styles.langGrid}`}>
          <div className={styles.claims}>
            <h2>Telugu stays Telugu.</h2>
            <h2>Hindi stays Hindi.</h2>
            <p className={styles.claimsNote}>
              Switch whenever it comes naturally. As Told keeps each language in the script you
              spoke instead of forcing the whole thought into one language.
            </p>
            <Link className={`textlink ${styles.afterLink}`} href="/languages">
              See multilingual voice →
            </Link>
          </div>

          <div className={styles.specimens}>
            <LanguageExample label="Telugu + English" lang="te">
              రేపు <En>office</En> కి కొంచెం <En>early</En> గా వెళ్లాలి. 10:30కి{' '}
              <En>client call</En> ఉంది. దాని ముందు <En>deck</En> ఒక్కసారి <En>check</En> చేసి{' '}
              <En>final numbers update</En> చేయాలి.
            </LanguageExample>

            <LanguageExample label="Hindi + English" lang="hi">
              इस <En>weekend</En> घर जाने का <En>plan</En> है, <En>but</En>{' '}
              <En>Saturday meeting</En> हुई तो <En>Sunday morning</En> निकलूँगा. <En>Tickets</En>{' '}
              अभी तक <En>book</En> नहीं की.
            </LanguageExample>
          </div>
        </div>

        {/* The claim, in the app. Two captures because the point is that neither
            script is the special case. */}
        <div className={`reveal ${styles.langShots}`}>
          <PhonePair fit>
            <PhoneFigure
              size="sm"
              src="/assets/shots/voice-light.webp"
              alt="A note in As Told titled Alaska trip idea, holding a spoken thought that moves between Telugu and English, transcribed in both scripts exactly as it was said."
              caption="Telugu + English"
            />
            <PhoneFigure
              size="sm"
              src="/assets/shots/hindi-light.webp"
              alt="A note in As Told titled Weekend plan, holding a spoken thought that moves between Hindi and English, with the Hindi kept in Devanagari."
              caption="Hindi + English"
            />
          </PhonePair>
        </div>
      </Section>

      {/* 7 — Organization + Privacy. Both are the same promise: nothing to manage. */}
      <Section tone="warm">
        <div className={styles.twoUp}>
          <div className={`reveal ${styles.half}`}>
            <h2>Nothing to organize.</h2>
            <p className={`lede ${styles.halfLede}`}>
              Notes appear in your timeline. Search when you remember the words, and the calendar is
              simply another way back to the day you wrote.
            </p>
            <PhonePair fit>
              <PhoneFigure
                size="sm"
                src="/assets/shots/search-light.webp"
                alt="Search in As Told: typing Seward narrows the timeline to the one note containing that word."
                caption="Search the words"
              />
              <PhoneFigure
                size="sm"
                src="/assets/shots/calendar-light.webp"
                alt="The As Told calendar for August 2026, with small dots under the days that have notes."
                caption="Jump to the day"
              />
            </PhonePair>
          </div>

          <div className={`reveal ${styles.half}`}>
            <h2>Your writing isn&rsquo;t an account.</h2>
            <p className={`lede ${styles.halfLede}`}>
              Open the app and write. Your note library lives on your iPhone, and Face ID is there
              when you want another layer.
            </p>
            <PhonePair>
              <PhoneFigure
                size="sm"
                src="/assets/shots/lock-light.webp"
                alt="The As Told lock screen: the feather mark, the As Told name, and an Unlock control."
                caption="Face ID, if you want it"
              />
            </PhonePair>
          </div>
        </div>

        {/* The four promises close the section across its full width. Kept in
            the privacy half they made that column 350px taller than its
            neighbour and left a hole under the timeline devices. */}
        <div className={`reveal ${styles.promises}`}>
          <PrivacyPromises />
          <Link className={`textlink ${styles.afterLink}`} href="/privacy">
            How privacy works →
          </Link>
        </div>
      </Section>

      {/* 8 — Light / Dark. The two devices say it; copy would only repeat them. */}
      <Section>
        <SectionIntro align="center" title="Yours, day or night." />
        <div className="reveal">
          <PhonePair>
            <PhoneFigure
              size="lg"
              src="/assets/shots/home-light.webp"
              alt="The As Told home screen in light mode."
              caption="Light"
            />
            <PhoneFigure
              size="lg"
              src="/assets/shots/home-dark.webp"
              alt="The same As Told home screen in dark mode."
              caption="Dark"
            />
          </PhonePair>
        </div>
      </Section>

      <FinalCTA />
    </>
  );
}
