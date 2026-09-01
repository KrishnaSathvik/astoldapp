import Link from 'next/link';
import { FeatureList } from '@/components/FeatureList';
import { FidelityBoundary, FidelityPromises } from '@/components/FidelityBoundary';
import { FinalCTA } from '@/components/FinalCTA';
import { PageHero } from '@/components/PageHero';
import { PhoneShot } from '@/components/PhoneShot';
import { ProductSplit } from '@/components/ProductSplit';
import { Section, SectionIntro } from '@/components/Section';
import { Steps } from '@/components/Steps';
import {
  ExampleGrid,
  ResultBullets,
  ResultChecklist,
  ResultHeading,
  ResultText,
  VoiceExample,
} from '@/components/VoiceExample';
import { pageMetadata } from '@/lib/site';
import styles from './page.module.css';

export const metadata = pageMetadata({
  title: 'Voice Notes for iPhone',
  description:
    'Start a voice note in one tap, pause and resume naturally, and get an ordinary note back. Designed for multilingual speech and code-switching, with recordings that survive a dropped connection.',
  path: '/voice',
});

/**
 * The deep dive on voice — seven sections, and deliberately not a second copy of
 * the homepage. It used to re-tell the whole product tour, including the same
 * multilingual specimens and the same two language-labelled devices; both pages
 * lost by it.
 *
 *   1  One tap from Home
 *   2  Pause. Think. Keep going.
 *   3  Your words become a note.          (new 2026-09-01)
 *   4  No language picker.
 *   5  Say the structure when you want it — and nothing else changes
 *   6  Your words shouldn't disappear.
 *   7  Your recording. Your choice.
 *
 * §3 is the frame the page was missing: the hero shows the recording, §2 shows
 * it paused, and nothing showed what the whole thing is *for* — an ordinary,
 * titleless note in the timeline. The homepage's *tap → speak → keep* sequence
 * ends on that screen; this page now does too, before it goes on to the rules.
 *
 * §4 carries no screenshot at all, on purpose. The claim is that there is
 * nothing to choose before you speak, and every device on this page already
 * proves it by having no language control on it (`RULES.md` §7, "Language
 * claims"). The tested groups are named in one place only, the Support answer.
 *
 * Every device is the same iPhone, the same dataset, the same morning as the
 * homepage (`docs/appstore/raw/library/`).
 */
export default function VoicePage() {
  return (
    <>
      <PageHero
        align="center"
        eyebrow="Voice"
        title="Or just say it."
        lede="When typing would slow the thought down, tap the microphone and talk. No blank note to create first, no language picker, and no separate voice inbox."
      >
        {/* The mechanic, in three words. No device up here since 2026-09-01: the
            hero carried the recording screen, which then appeared again two
            sections down and on the homepage — the page opened on a picture the
            visitor had just left. The first device is now the first section. */}
        <div className={`reveal ${styles.heroShot}`}>
          <Steps center items={['Tap', 'Speak', 'Keep it']} />
        </div>
      </PageHero>

      {/* 1 — Quick Voice: the entry point with no typing in it at all. The
          device is the recording itself, not Home — Home is the homepage's hero
          and the copy already says where the button is. */}
      <Section tone="warm">
        <ProductSplit
          eyebrow="From the home screen"
          title="One tap from Home."
          lede="The microphone sits beside the new-note button. Tap it and As Told is already listening — no blank editor, no keyboard rising, and no note existing until there are words to put in one."
          media={
            <PhoneShot
              size="lg"
              priority
              src="/assets/shots/quickvoice-light.webp"
              alt="As Told recording: Cancel at the top, an elapsed time of 00:21, the word Listening, a live level meter, and Pause beside a round stop button."
            />
          }
        >
          <p className={styles.para}>
            Start from Home and voice creates a new note. Start inside a note you&rsquo;re already
            writing and the transcript arrives at the cursor — or at the end, if you were only
            reading.
          </p>
          <p className={styles.para}>
            Cancel, a declined microphone, silence, or a failure all leave your timeline exactly as
            it was.
          </p>
        </ProductSplit>
      </Section>

      {/* 2 — Pause / resume. */}
      <Section tone="warm">
        <ProductSplit
          reverse
          eyebrow="Pause and resume"
          title="Pause. Think. Keep going."
          lede="Stop for as long as you need and pick the same recording back up. It stays one continuous recording, and only the time you were actually speaking counts."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/quickvoice-paused-light.webp"
              alt="The same As Told recording held at 00:23 and marked Paused, with Cancel above and Resume beside a round stop button."
            />
          }
        >
          <FeatureList
            variant="rule"
            items={[
              'A call, Siri, or leaving the note finishes the recording rather than discarding it',
              'Backgrounding the app finishes it too, paused or not',
              'Plugging in headphones mid-thought does not end it',
              'Up to five minutes in one recording',
            ]}
          />
        </ProductSplit>
      </Section>

      {/* 3 — What it is all for. The finished note, as it lands: titleless,
          three paragraphs, nothing marking it as spoken. */}
      <Section>
        <ProductSplit
          eyebrow="What comes back"
          title="Your words become a note."
          lede="Tap Done and the recording is an ordinary note — an empty title you can fill in or leave, paragraphs you can edit, Share in the corner like any other note. It sits in your timeline beside everything you typed."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/voice-note-light.webp"
              alt="A note in As Told created by voice: the title field still reads Title, and below it three spoken paragraphs — Saturday kept simple, a stop at the market for dinner, Sunday left open — with the keyboard down."
            />
          }
        >
          <p className={styles.para}>
            There is no separate voice-note library and no transcript screen to visit. Nothing
            marks the note as spoken afterwards, either — no microphone badge on the row, no Voice
            filter, no voice-notes folder. It is a note.
          </p>
        </ProductSplit>
      </Section>

      {/* 4 — Multilingual. Three principles, no specimens and no device: naming
          languages here is what made the site read as a three-language product,
          and putting a note in a particular script under this heading does the
          same job with a picture (`RULES.md` §7, "Language claims"). The tested
          groups are named in one place only, the Support answer. */}
      <Section tone="warm">
        <SectionIntro
          eyebrow="Multilingual"
          title="No language picker."
          lede="As Told is built for multilingual speech and natural code-switching. You don't choose a language before you start, and As Told doesn't translate what you said into a different one — speak in one language, switch in the middle of a thought, or mix them the way you normally do."
          wide
        />
        <div className={`reveal ${styles.principles}`}>
          <span>No language picker</span>
          <span>Switch naturally</span>
          <span>No forced translation</span>
        </div>
        <p className={`reveal ${styles.note} ${styles.para}`}>
          Multilingual and mixed-language voice is tested before every release. Accuracy varies
          with the language, the accent, the recording conditions, and how the speech is mixed.
        </p>
      </Section>

      {/* 5 — What voice changes, and what it doesn't. Three spoken commands,
          not the whole command matrix — that belongs in Support — and then the
          verbatim contract, which is the same subject: structure when you ask
          for it, and your words untouched either way. */}
      <Section>
        <SectionIntro
          eyebrow="Spoken structure"
          title="Say the structure when you want it."
          lede="Ask for a heading, a new paragraph, a list or a checklist and the next thing you say takes that shape. Otherwise As Told keeps your words as ordinary writing."
        />
        <div className="reveal">
          <ExampleGrid>
            <VoiceExample said="Heading. Japan trip.">
              <ResultHeading>Japan trip</ResultHeading>
            </VoiceExample>
            <VoiceExample said="Bullet list. Rain jacket. Next item. Camera.">
              <ResultBullets items={['Rain jacket', 'Camera']} />
            </VoiceExample>
            <VoiceExample said="Checklist. Reserve hotels. Next item. Book rail passes.">
              <ResultChecklist items={['Reserve hotels', 'Book rail passes']} />
            </VoiceExample>
            <VoiceExample said="My checklist is getting too long.">
              <ResultText>My checklist is getting too long.</ResultText>
            </VoiceExample>
          </ExampleGrid>
          <p className={`${styles.para} ${styles.note}`}>
            Only a clear, standalone command counts — ordinary speech that merely mentions one of
            those words is left alone. A missed command is recoverable; a phantom one rewrites your
            note.{' '}
            <Link className="textlink" href="/support">
              Every command is listed in Support →
            </Link>
          </p>
        </div>

        <div className={`reveal ${styles.fidelity}`}>
          <div>
            <h3 className={styles.subhead}>And nothing else is touched.</h3>
            <p className={styles.para}>
              Punctuation, capitalization and paragraph breaks are added so a spoken thought reads
              like written language — and that is the whole of it. Your slang, your names, your
              repetitions and your filler words stay in. Nothing is tidied up, and nothing is
              turned into a different language on the way.
            </p>
            <FidelityPromises />
          </div>
          <FidelityBoundary />
        </div>
      </Section>

      {/* 6 — Durability. */}
      <Section tone="warm">
        <ProductSplit
          reverse
          eyebrow="If something goes wrong"
          title="Your words shouldn't disappear."
          lede="If transcription fails on a dropped connection, As Told keeps the recording on your iPhone and offers Retry or Delete Recording — so a network error is not how a thought gets lost."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/retry-light.webp"
              alt="As Told after a failed transcription: over a note called Weekend Plan, a sheet reads that a connection is needed to transcribe this recording and that your recording is still on this iPhone, above Delete Recording and Retry."
            />
          }
        >
          <p className={styles.para}>
            If the app closes before you answer, you&rsquo;re offered it once more the next time
            you open As Told.
          </p>
          <p className={`${styles.para} ${styles.note}`}>
            Nothing is uploaded in the background while it waits. A recording kept for a retry is
            removed within 24 hours whether you come back to it or not, and there is still no
            recordings library and nothing to manage.
          </p>
        </ProductSplit>
      </Section>

      {/* 7 — Consent: what stays on the phone, and the one thing that leaves. */}
      <Section>
        <ProductSplit
          eyebrow="What happens to the recording"
          title="Your recording. Your choice."
          lede="Recording locally sends nothing. Transcription needs more computing power than a phone should spend, so when you choose it the audio goes over an encrypted connection to OpenAI, comes back as text, and is not kept."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/consent-light.webp"
              alt="As Told asking permission before sending a recording: a Voice transcription sheet explaining that the audio goes to OpenAI and that nothing else from the note is sent, with Cancel and Continue."
            />
          }
        >
          <p className={styles.para}>
            Nothing else from your note goes with it — no title, no existing text, no search
            history. The first time you finish a recording, As Told says so plainly and waits for
            your answer. You answer once.
          </p>
          <Link className={`textlink ${styles.afterLink}`} href="/privacy">
            Read privacy →
          </Link>
        </ProductSplit>
      </Section>

      <FinalCTA title="Say it however it comes." />
    </>
  );
}
