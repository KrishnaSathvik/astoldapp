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
    'Write normally, speak naturally, keep structure when you want it, and find notes again by day. As Told is a private iPhone notes app with multilingual voice transcription, checklists, tables, code and a calendar.',
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
  ['Checklists', 'A circle beside the line. Tick it in place; it stays where you put it.'],
  ['Links & tables', 'A pasted table stays a table; a link stays tappable.'],
  ['Code blocks', 'Monospaced, syntax-coloured, and yours to edit.'],
] as const;

/** The two ways back to a note. Search and the calendar, and nothing to maintain. */
const FINDING = [
  'Search, when you remember a word.',
  'The calendar, when you remember the day.',
  'No folders, no tags, nothing to keep tidy.',
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
 * Nine sections, and no more (rebuilt 2026-09-01 around the V2.1 raw library,
 * `docs/appstore/raw/library/`).
 *
 *   1  Hero — Home, the whole product in one screen
 *   2  Write or speak — the two ways into a note, and what comes back
 *   3  Pause. Think. Keep going. — voice as it actually feels, languages as copy
 *   4  Structure — the Japan Trip note: heading, circles, numbers, bullets
 *   5  Paste + code
 *   6  Find it again — Home's recent days, and the calendar
 *   7  Light / Dark
 *   8  Your words shouldn't disappear — the retained recording, small
 *   9  Share + privacy — what leaves, and what doesn't  →  Final CTA
 *
 * Two changes of principle against the 2026-08-29 page. The **calendar** is on
 * the page for the first time: it earned a section when it gained the density
 * dots and its own accent, and "find it again" was the one movement of the
 * product story that had no picture. And the **recovery state is a screenshot
 * again**, not a two-line card — kept small (`md`) and late, because it is a
 * trust signal rather than a hero, but a real one: the copy on that sheet is
 * the promise, and a drawn card of it read as a mock-up.
 *
 * Every device is the same iPhone, the same dataset, the same morning. The
 * notes are a person's — a weekend, a trip, a launch, a budget, a query, a book
 * — and the spoken note in §2 is the one on Home's second row, so the sequence
 * *tap → speak → keep* ends on the screen the page opened with.
 *
 * None of them is a note in a non-Latin script. A note in a particular script
 * *is* the language claim whatever the caption says, and two of them on one page
 * once taught a reader that As Told is an English + Telugu + Hindi app
 * (`RULES.md` §7, "Language claims"). The multilingual argument is made by the
 * recording screen instead, which has no language control on it.
 *
 * The bands are grouped rather than alternating (warm warm · plain plain · warm
 * · plain · plain · warm). A stripe every few hundred pixels chops the page into
 * a dozen unrelated blocks; a band per movement gives it four.
 */
export default function HomePage() {
  return (
    <>
      {/* 1 — Hero */}
      <Hero
        eyebrow="Private notes for iPhone"
        title="Anything you want to put into words."
        lede="Write normally. Speak naturally. Give a note structure when you want it, and find it again by the day you wrote it — in a notes app that keeps your words exactly as you put them."
        shot={{
          src: '/assets/shots/home-light.webp',
          alt: 'The As Told home screen on August 31: calendar, new-note and microphone buttons in the header; Today holding Weekend Plan and a spoken note; Previous 7 Days holding Japan Trip, Launch Checklist, Monthly Units Query, an untitled note and Book Notes, then Show all 9; a search field pinned at the bottom.',
        }}
      />

      {/* 2 — The two ways in. One header, two buttons, and the whole product.
          The only three-device sequence on the site, and it ends where the
          page began: the spoken note in the third frame is Home's second row. */}
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
              src="/assets/shots/checklist-light.webp"
              alt="A typed note in As Told called Launch Checklist: a sentence, then five items drawn as circles with two of them ticked, and a closing sentence."
              caption="Write"
            />
            <PhoneFigure
              size="sm"
              src="/assets/shots/quickvoice-light.webp"
              alt="As Told recording: Cancel at the top, an elapsed time of 00:21, the word Listening, a live level meter, and Pause beside a round stop button."
              caption="Speak"
            />
            <PhoneFigure
              size="sm"
              src="/assets/shots/voice-note-light.webp"
              alt="The finished note: what was spoken, as an ordinary note with an empty title and three paragraphs — Saturday kept simple, a stop at the market, Sunday left open — with the keyboard down and Share in the corner."
              caption="Keep"
            />
          </PhonePair>
        </div>
        <p className={`reveal ${styles.coda}`}>
          What comes back is a note — not a recording in a list, not a transcript screen to visit.
          Add a title or leave it empty, edit it like anything else you typed. Speaking inside a
          note works the same way: put the cursor where the thought belongs, tap the mic on the
          writing toolbar, and your words land there.
        </p>
      </Section>

      {/* 3 — Voice as it feels. Pause is the device; languages are the copy.
          The recording screen is the multilingual proof too: there is no
          language picker on it, because there is nothing to pick. A screenshot
          of a note in a particular script would only have taught the reader
          which languages are allowed (`RULES.md` §7, "Language claims"). */}
      <Section tone="warm">
        <ProductSplit
          eyebrow="Voice"
          title="Pause. Think. Keep going."
          lede="Stop for as long as you need and pick the same recording back up — it stays one continuous recording, and only the time you were actually speaking counts. And you never choose a language before you start: speak in one, switch in the middle of a sentence, or mix them the way you normally do."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/quickvoice-paused-light.webp"
              alt="The same As Told recording held at 00:23 and marked Paused, with Cancel above and Resume beside a round stop button. Nothing on the screen asks which language is being spoken."
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
          <Link className={`textlink ${styles.afterLink}`} href="/voice">
            Explore voice →
          </Link>
        </ProductSplit>
      </Section>

      {/* 4 — Structure. The note itself, not the toolbar: a heading, a line of
          prose, four circles, a numbered route and a packing list, on one
          screen with the keyboard down. The toolbar is described in words. */}
      <Section>
        <ProductSplit
          reverse
          eyebrow="Structure"
          title="Structure when you need it."
          lede="Headings, lists and checklists come from a small writing toolbar that sits just above the keyboard — As Told's own, not a row bolted onto Apple's. A note can stay a paragraph, or become a plan with a route, a packing list and things to tick off, and it still reads like a note."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/structure-light.webp"
              alt="A note in As Told called Japan Trip: a Before we book heading over a line of prose, a checklist of four items drawn as circles with Compare flights ticked, a numbered Route of Tokyo, Kyoto and Osaka, and a bulleted Pack list — all on one screen."
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
            alt="A pasted note in As Told called Trip Budget: a sentence, then a two-column table of Item and Estimate — Flights $980, Hotel $1,400, Rental car $650, Activities $340 — and a Still to price heading with three bullets under it."
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
            alt="A note in As Told called Monthly Units Query: a line of prose, then a syntax-coloured SQL card labelled SQL with a Copy Code control, holding a SELECT statement over the orders table, and a line of prose below it."
          />
        </div>
      </Section>

      {/* 6 — Find it again. Home keeps the recent days; the calendar reaches
          further back. New on 2026-09-01: the calendar had never been on the
          page, and this was the movement of the story with no picture. */}
      <Section tone="warm">
        <ProductSplit
          reverse
          eyebrow="Find it again"
          title="Find what you wrote, by day."
          lede="Home keeps the recent days in view — Today, then the previous seven. The calendar takes you further back by the day you wrote something, not by the folder you should have filed it in: a dot for a day with notes, more for a busier one, and the day's notes right under the month when you tap it."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/calendar-light.webp"
              alt="The As Told calendar for August 2026, in sage green: the 26th, 27th, 29th and 30th carry one to three dots, the 31st is selected, and under the month that day's notes are listed — Weekend Plan, a spoken note, and Japan Trip."
            />
          }
        >
          <FeatureList variant="rule" items={FINDING} />
        </ProductSplit>
      </Section>

      {/* 7 — Light / Dark. The two devices say it; copy would only repeat them.
          The same note, the same scroll position — a pair, not two pictures. */}
      <Section>
        <SectionIntro align="center" title="Yours, day or night." />
        <div className="reveal">
          <PhonePair>
            <PhoneFigure
              size="lg"
              src="/assets/shots/structure-light.webp"
              alt="The Japan Trip note in As Told in light mode: a heading, a line of prose, a circular checklist, a numbered route and a bulleted packing list."
              caption="Light"
            />
            <PhoneFigure
              size="lg"
              src="/assets/shots/structure-dark.webp"
              alt="The same As Told note in dark mode, at the same scroll position."
              caption="Dark"
            />
          </PhonePair>
        </div>
      </Section>

      {/* 8 — Durability. A real capture of the retained-recording sheet, kept
          small and late: it is a trust signal, not a hero. The two-line drawn
          card it replaces read as a mock-up of a screen the app really has. */}
      <Section tight>
        <ProductSplit
          eyebrow="If something goes wrong"
          title="Your words shouldn't disappear."
          lede="A call, Siri, leaving the note or locking the phone finishes a recording rather than throwing it away. And if transcription fails — a dropped connection, a lift with no signal — As Told keeps the recording on your iPhone and offers Retry, instead of losing what you already said."
          media={
            <PhoneShot
              size="md"
              src="/assets/shots/retry-light.webp"
              alt="As Told after a failed transcription: over a note called Weekend Plan, a sheet reads that a connection is needed to transcribe this recording and that your recording is still on this iPhone, above Delete Recording and Retry."
            />
          }
        >
          <p className={styles.aside}>
            Nothing is uploaded in the background while it waits. A recording kept for a retry is
            removed within 24 hours whether you come back to it or not — and there is still no
            recordings library and nothing to manage.
          </p>
        </ProductSplit>
      </Section>

      {/* 9 — What leaves, and what doesn't. Share carries no device: the sheet
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

      <FinalCTA title="Your thoughts. Your words. As told." />
    </>
  );
}
