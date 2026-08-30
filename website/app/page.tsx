import Link from 'next/link';
import { FeatureList } from '@/components/FeatureList';
import { FinalCTA } from '@/components/FinalCTA';
import { Hero } from '@/components/Hero';
import { PhoneFigure, PhonePair, PhoneShot } from '@/components/PhoneShot';
import { ProductSplit } from '@/components/ProductSplit';
import { Section, SectionIntro } from '@/components/Section';
import { pageMetadata } from '@/lib/site';
import styles from './page.module.css';

export const metadata = pageMetadata({
  title: 'As Told — Private Notes, Voice & Writing for iPhone',
  description:
    'Write, speak, paste and keep your thoughts in one private iPhone notes app. As Told supports structured writing, multilingual voice transcription, code, tables, links and more.',
  path: '/',
});

/**
 * What voice does, in four lines that name no language.
 *
 * Pause/resume sits at the top of this list rather than in a section of its own,
 * because a visitor is being told one thing here: *say it however it comes*.
 * The three below it replaced a row of five chips — Telugu · Hindi · Telugu +
 * English · Hindi + English · English — which every visitor read as the
 * supported-language list no matter what the footnote underneath said. Those
 * five are the *tested* groups, and tested groups are release evidence, not a
 * product boundary; they are named in exactly one place now, the Support answer
 * for "Which languages can I speak?" (`RULES.md` §7, "Language claims").
 */
const VOICE = [
  ['Pause & resume', 'Stop mid-thought and pick the same recording back up.'],
  ['No language picker', 'Nothing to choose before you start talking.'],
  ['Switch naturally', 'Move between languages inside one sentence.'],
  ['No forced translation', 'Your words come back in the language you used.'],
] as const;

/** The shapes a note takes. Four labels, not a nine-chip vocabulary list. */
const WRITING = [
  ['Headings & lists', 'Aa for Heading and Subheading; bullets and numbers one tap each.'],
  ['Checklists', 'Tick them in place. They stay where you put them.'],
  ['Links & tables', 'A pasted table stays a table; a link stays tappable.'],
  ['Code blocks', 'Monospaced, syntax-coloured, and yours to edit.'],
] as const;

/**
 * The privacy claims, as five lines rather than three cards. At half the width
 * of the page they have to be short, and short is what they should have been:
 * the longest of these used to run to three lines of a paragraph nobody
 * finishes.
 */
const PRIVACY = [
  'Your notes stay on your iPhone.',
  'No As Told account, ever.',
  'A recording is sent for transcription only after you say yes.',
  'Nothing else from the note goes with it — no title, no existing text.',
  'Audio kept for a retry is removed within 24 hours.',
] as const;

/**
 * Seven sections, and no more.
 *
 *   1  Hero
 *   2  Write or speak — the two ways into a note
 *   3  Voice — pause/resume, languages and durability, as one argument
 *   4  Writing
 *   5  Paste + code
 *   6  Share + privacy — what leaves, and what doesn't
 *   7  Light / Dark  →  Final CTA
 *
 * It was nine on 2026-08-29, and voice was split across three of them: a
 * multilingual band, a reliable-voice band, and the sequence in §2. Splitting
 * one capability into three stripes is what makes a page read as a feature tour
 * — so pause, languages and recovery are one section now, because they are one
 * sentence: *say it however it comes, and it won't get lost*. Share and privacy
 * merged for the same reason; Share is a system sheet and one paragraph, which
 * never justified a stripe of its own.
 *
 * Nine captures carry it, in ten places, every one drawn at `lg` or larger.
 * `home-light` is the only file shown twice — as the hero, then as the first
 * step of the sequence — because that is the same screen doing two jobs.
 *
 * None of them is a note in a non-Latin script. `voice-light` (a spoken
 * Telugu/English note) closed the sequence until 2026-08-29 and `hindi-light`
 * illustrated the multilingual section; both are gone from `public/`. A note in
 * a particular script *is* the language claim whatever the caption says, and
 * two of them on one page taught a reader that As Told is an English + Telugu +
 * Hindi app (`RULES.md` §7, "Language claims"). The multilingual argument is
 * made by the recording screen instead, which has no language control on it.
 *
 * The bands are grouped rather than alternating (plain · warm warm · plain plain
 * · warm · plain). A stripe every few hundred pixels chops the page into a dozen
 * unrelated blocks; a band per movement gives it three.
 */
export default function HomePage() {
  return (
    <>
      {/* 1 — Hero */}
      <Hero
        eyebrow="Private notes for iPhone"
        title="Anything you want to put into words."
        lede="A quiet place for notes, thoughts, lists, code, plans and everything else you want to keep — without turning writing into a workspace."
        shot={{
          src: '/assets/shots/home-light.webp',
          alt: 'The As Told home screen: a library of ordinary notes grouped by day — Japan Trip, Launch Checklist, SQL Questions, Book Ideas — with a new-note button and a microphone side by side in the header and a search field pinned at the bottom.',
        }}
      />

      {/* 2 — The two ways in. One header, two buttons, and the whole product.
          The only three-device sequence on the site. */}
      <Section id="writing" tone="warm">
        <SectionIntro
          eyebrow="Two ways in"
          title="Write it. Or just say it."
          lede="Some thoughts are easier to type. Others are easier to say. Tap the pencil to start writing, or tap the microphone and start talking straight away — no note to create first, no editor to sit through."
        />
        <div className="reveal">
          <PhonePair fit>
            <PhoneFigure
              size="sm"
              src="/assets/shots/home-light.webp"
              alt="The As Told home screen, with a new-note button and a microphone beside each other in the header, above a timeline of everyday notes."
              caption="Write"
            />
            <PhoneFigure
              size="sm"
              src="/assets/shots/quickvoice-light.webp"
              alt="As Told recording: Cancel at the top, an elapsed time of 00:17, the word Listening, a live level meter, and Pause beside a round stop button."
              caption="Speak"
            />
            <PhoneFigure
              size="sm"
              src="/assets/shots/note-light.webp"
              alt="The finished note: what was spoken, transcribed into an ordinary note called Ideas for Sunday — three paragraphs of plain text with the keyboard down."
              caption="Keep"
            />
          </PhonePair>
        </div>
        <p className={`reveal ${styles.coda}`}>
          What comes back is a note — not a recording in a list, not a transcript screen to visit.
          Speaking inside a note works the same way: put the cursor where the thought belongs, tap
          the mic on the writing toolbar, and your words land there.
        </p>
      </Section>

      {/* 3 — Voice, whole. Pause, languages and recovery are the same promise,
          and the device carrying it is the recording screen — which is the
          multilingual proof too: there is no language picker on it, because
          there is nothing to pick. A screenshot of a note in a particular
          script would only have taught the reader which languages are allowed
          (`RULES.md` §7, "Language claims"). */}
      <Section tone="warm">
        <ProductSplit
          eyebrow="Voice"
          title="Say it however it comes."
          lede="Pause when you need a moment and resume when the thought comes back — it stays one continuous recording, and only the time you were actually speaking counts. And you never choose a language before you start: speak in one, switch in the middle of a sentence, or mix them the way you normally do."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/quickvoice-paused-light.webp"
              alt="The same As Told recording held at 00:18 and marked Paused, with Cancel above and Resume beside a round stop button. Nothing on the screen asks which language is being spoken."
            />
          }
        >
          <dl className={styles.principles}>
            {VOICE.map(([term, detail]) => (
              <div key={term}>
                <dt>{term}</dt>
                <dd>{detail}</dd>
              </div>
            ))}
          </dl>
          <p className={styles.aside}>
            Multilingual and mixed-language voice is tested before every release. Accuracy varies
            with the language, the accent, the recording conditions, and how the speech is mixed.
          </p>
        </ProductSplit>

        {/* Durability, as one paragraph and the two controls it actually is —
            not a full capture of the failure screen. A marketing page that
            shows its own error state at device size is telling you what to
            expect from the feature. */}
        <div className={`reveal ${styles.reliability}`}>
          <p className={styles.body}>
            A call, Siri, leaving the note or locking the phone finishes the recording rather than
            throwing it away. And if transcription fails — a dropped connection, a lift with no
            signal — As Told keeps that recording on your iPhone so you can try again, instead of
            losing what you already said.
          </p>
          <div className={styles.recovery}>
            <p className={styles.recoveryLine}>Your recording is still on this iPhone.</p>
            <p className={styles.recoveryActions}>
              <span>Retry</span>
              <span>Delete Recording</span>
            </p>
          </div>
        </div>
        <Link className={`reveal textlink ${styles.afterLink}`} href="/voice">
          Explore voice →
        </Link>
      </Section>

      {/* 4 — Writing. The toolbar, described as what it actually is. */}
      <Section>
        <ProductSplit
          reverse
          eyebrow="Writing"
          title="More than plain text. Still simple."
          lede="A writing toolbar sits just above the keyboard — As Told's own, not a row bolted onto Apple's. Give a thought as much structure as it needs, and no more."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/toolbar-light.webp"
              alt="The As Told writing toolbar floating above the iPhone keyboard: an Aa style button, then bulleted list, numbered list and checklist buttons with the bulleted one highlighted, a divider, and a microphone. The caret sits in the last bullet of the note above."
            />
          }
        >
          <dl className={styles.labels}>
            {WRITING.map(([term, detail]) => (
              <div key={term}>
                <dt>{term}</dt>
                <dd>{detail}</dd>
              </div>
            ))}
          </dl>
          {/* Links, tables and code are not toolbar buttons and are not coming
              (RULES.md §7). Without this line the four labels read as a promise
              of a Table button and a Code button. */}
          <p className={styles.aside}>
            No block picker. No database. No setup. No bold, italic or font menu either — and the
            last two shapes arrive with your text rather than from a button, because a table and a
            block of code are things you bring, not styles you apply.
          </p>
        </ProductSplit>
      </Section>

      {/* 5 — Paste, including code. A capability people arrive with. */}
      <Section>
        <div className={`reveal ${styles.pasteGrid}`}>
          <PhoneShot
            size="lg"
            src="/assets/shots/table-light.webp"
            alt="A pasted note in As Told called Trip budget: a Fixed costs subheading above a two-column table of Item and Estimate rows — Hotel $1,400, Rental car $650, Boat tour $229, Flights $980 — then a Still to price checklist."
          />
          <div className={styles.pasteCopy}>
            <span className="eyebrow">Paste</span>
            <h2>Paste it. Keep the useful structure.</h2>
            <p className="lede">
              Copy a plan out of a chat, a table out of a browser, a query out of a terminal. When
              the clipboard says what those lines were, As Told keeps every shape it has a place
              for — headings, paragraph breaks, lists, checklists you can still tick, tables as
              tables, links still tappable.
            </p>
            <p className={styles.aside}>
              Bold, italic, colours and page layout have nowhere to go in a note, so they simplify
              to text. Plain text arrives exactly as it was — nothing is inferred from it, and your
              words are never rewritten because you pasted them.
            </p>
          </div>
        </div>

        <div className={`reveal ${styles.codeSplit}`}>
          <div className={styles.pasteCopy}>
            <span className="eyebrow">Code</span>
            <h2>Code that still looks like code.</h2>
            <p className="lede">
              A fenced block arrives as a card: monospaced, indented exactly as it was written,
              syntax-coloured, with the language named and <strong>Copy Code</strong> in the
              corner. Long lines scroll instead of wrapping into nonsense, and you keep writing
              prose around it.
            </p>
            <p className={styles.aside}>
              No console, no compiler, no autocomplete, no linting. As Told does not run your code
              — it just refuses to destroy it.
            </p>
          </div>
          <PhoneShot
            size="lg"
            src="/assets/shots/code-light.webp"
            alt="A note in As Told called Monthly units query: a line of prose, then a syntax-coloured SQL card labelled SQL with a Copy Code control, holding a SELECT statement over the orders table — with ordinary prose above it and below it."
          />
        </div>
      </Section>

      {/* 6 — What leaves, and what doesn't. Share carries no device: the sheet
          on screen is iOS's, and a simulator capture of it would name
          destinations a real phone doesn't have (website README, "Known
          gaps"). */}
      <Section tone="warm">
        <div className={`reveal ${styles.trust}`}>
          <div className={styles.trustCopy}>
            <span className="eyebrow">Share</span>
            <h2>When a note needs to leave.</h2>
            <p className="lede">
              Tap Share and iOS takes over. A note can go to whichever apps and services are
              already available on your iPhone — with its formatting where the destination can take
              it, and plain text everywhere else.
            </p>
            <p className={styles.aside}>
              It is the iPhone&rsquo;s own sheet, not a menu of ours — no destination picker, no
              &ldquo;export as&rdquo;, no social buttons. As Told creates no link, hosts nothing,
              and keeps no record of what you sent or where it went.
            </p>
          </div>

          <div className={styles.trustCopy}>
            <span className="eyebrow">Private by default</span>
            <h2>Your notes are yours.</h2>
            <p className="lede">
              No sign-up, no cloud library of your writing, and one thing that leaves the phone —
              only when you ask for it.
            </p>
            <FeatureList variant="rule" items={PRIVACY} />
            <p className={styles.aside}>
              No ads, no analytics, and no third-party SDK of any kind. Nothing you write is used
              to build a profile of you.
            </p>
            <Link className={`textlink ${styles.afterLink}`} href="/privacy">
              Read our privacy policy →
            </Link>
          </div>
        </div>
      </Section>

      {/* 7 — Light / Dark. The two devices say it; copy would only repeat them. */}
      <Section>
        <SectionIntro align="center" title="Yours, day or night." />
        <div className="reveal">
          <PhonePair>
            <PhoneFigure
              size="lg"
              src="/assets/shots/structure-light.webp"
              alt="A note in As Told in light mode: a heading, a line of prose, a checklist, a numbered list and a bulleted packing list."
              caption="Light"
            />
            <PhoneFigure
              size="lg"
              src="/assets/shots/structure-dark.webp"
              alt="The same As Told note in dark mode."
              caption="Dark"
            />
          </PhonePair>
        </div>
      </Section>

      <FinalCTA title="Your thoughts. Your words. As told." />
    </>
  );
}
