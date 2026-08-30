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
    'Start a voice note in one tap, pause and resume naturally, and turn speech into ordinary notes. Designed for multilingual speech and code-switching.',
  path: '/voice',
});

/**
 * The deep dive on voice — six sections, and deliberately not a second copy of
 * the homepage. It used to re-tell the whole product tour, including the same
 * multilingual specimens and the same two language-labelled devices; both pages
 * lost by it.
 *
 *   1  One tap from Home — and where the transcript lands
 *   2  Pause. Think. Keep going.
 *   3  No language picker.
 *   4  Say the structure when you want it — and nothing else changes
 *   5  Your words shouldn't disappear.
 *   6  Your recording. Your choice.
 *
 * Eight until 2026-08-29. "Your voice lands where you mean it" was a band and a
 * device of its own for one fact — the transcript arrives at the cursor — which
 * is a sentence inside §1, not a section. The verbatim contract moved out of the
 * multilingual section and into §4, where it belongs: a *said → written*
 * comparison sitting under a heading about languages made the section read as a
 * language demo, and what it actually demonstrates is that nothing gets
 * rewritten.
 *
 * §3 carries no screenshot at all, on purpose. The claim is that there is
 * nothing to choose before you speak, and every device on this page already
 * proves it by having no language control on it (`RULES.md` §7, "Language
 * claims").
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
        <div className={`reveal ${styles.heroShot}`}>
          <PhoneShot
            size="xl"
            priority
            src="/assets/shots/quickvoice-light.webp"
            alt="As Told recording: Cancel at the top, an elapsed time of 00:17, the word Listening, a live level meter, and Pause beside a round stop button."
          />
          {/* The mechanic, in three words, directly under the thing doing it.
              This is the whole page in one line; everything below elaborates. */}
          <Steps center items={['Tap', 'Speak', 'Keep it']} />
        </div>
      </PageHero>

      {/* 1 — Quick Voice: the entry point with no typing in it at all, and
          where what you said ends up. */}
      <Section tone="warm">
        <ProductSplit
          eyebrow="From the home screen"
          title="One tap from Home."
          lede="The microphone sits beside the new-note button. Tap it and As Told is already listening — no blank editor, no keyboard rising, and no note existing until there are words to put in one."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/home-light.webp"
              alt="The As Told home screen, with a calendar, a new-note button and a microphone grouped in the header above the timeline of notes."
            />
          }
        >
          <p className={styles.para}>
            Start from Home and voice creates a new note. Start inside a note you&rsquo;re already
            writing and the transcript arrives at the cursor — or at the end, if you were only
            reading. Either way what comes back is ordinary, editable text: there is no separate
            voice-note library and no transcript screen to visit.
          </p>
          <p className={styles.para}>
            Cancel, a declined microphone, silence, or a failure all leave your timeline exactly as
            it was. Nothing marks the note as spoken afterwards, either — no microphone badge on
            the row, no Voice filter, no voice-notes folder. It is a note.
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
              alt="The same As Told recording held at 00:18 and marked Paused, with Cancel above and Resume beside a round stop button."
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

      {/* 3 — Multilingual. Three principles, no specimens and no device: naming
          languages here is what made the site read as a three-language product,
          and putting a note in a particular script under this heading does the
          same job with a picture (`RULES.md` §7, "Language claims"). The tested
          groups are named in one place only, the Support answer. */}
      <Section>
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

      {/* 4 — What voice changes, and what it doesn't. Three spoken commands,
          not the whole command matrix — that belongs in Support — and then the
          verbatim contract, which is the same subject: structure when you ask
          for it, and your words untouched either way. */}
      <Section tone="warm">
        <SectionIntro
          eyebrow="Spoken structure"
          title="Say the structure when you want it."
          lede="Ask for a heading, a new paragraph, a list or a checklist and the next thing you say takes that shape. Otherwise As Told keeps your words as ordinary writing."
        />
        <div className="reveal">
          <ExampleGrid>
            <VoiceExample said="Heading. Alaska trip.">
              <ResultHeading>Alaska trip</ResultHeading>
            </VoiceExample>
            <VoiceExample said="Bullet list. Anchorage. Next item. Seward.">
              <ResultBullets items={['Anchorage', 'Seward']} />
            </VoiceExample>
            <VoiceExample said="Checklist. Call Ravi. Next item. Buy groceries.">
              <ResultChecklist items={['Call Ravi', 'Buy groceries']} />
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

      {/* 5 — Durability. */}
      <Section>
        <ProductSplit
          reverse
          eyebrow="If something goes wrong"
          title="Your words shouldn't disappear."
          lede="If transcription fails on a dropped connection, As Told keeps the recording on your iPhone and offers Retry or Delete Recording — so a network error is not how a thought gets lost."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/retry-light.webp"
              alt="As Told after a failed transcription: over a note called Weekend in Seattle, a card reads that a connection is needed to transcribe this recording and that your recording is still on this iPhone, above Delete Recording and Retry."
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

      {/* 6 — Consent. */}
      <Section tone="warm">
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
