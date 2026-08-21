import Link from 'next/link';
import { FidelityBoundary, FidelityPromises } from '@/components/FidelityBoundary';
import { FinalCTA } from '@/components/FinalCTA';
import { LanguageChips } from '@/components/LanguageExample';
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
  title: 'Voice notes for iPhone — speak your notes',
  description:
    'Speak a note instead of typing it. As Told turns your voice into editable text in the same note, with natural punctuation and no rewriting — in English, Telugu, Hindi, and mixed speech.',
  path: '/voice',
});

export default function VoicePage() {
  return (
    <>
      <PageHero
        align="center"
        eyebrow="Voice"
        title="Or just say it."
        lede="Speak into the note you're already writing. Tap the mic, talk the way you normally talk, and keep going."
      >
        <div className={`reveal ${styles.heroShot}`}>
          <PhoneShot
            size="xl"
            priority
            src="/assets/shots/recording-light.webp"
            alt="The As Told recording panel over the note being written: a level meter, an elapsed time of 00:01, and Cancel and Done controls."
          />
          {/* The mechanic, in three words, directly under the thing doing it.
              This is the whole page in one line; everything below elaborates. */}
          <Steps center items={['Cursor', 'Speak', 'Keep writing']} />
        </div>
      </PageHero>

      <Section tone="warm">
        <ProductSplit
          reverse
          /* `/languages` owns "Your voice lands where your cursor is." — the same
             H2 on two pages was competing with itself. The mechanic still leads
             the lede here; this section's own payload is that what returns is
             ordinary editable text, not a transcript to manage. */
          title="It comes back as ordinary text."
          lede="If the cursor is somewhere in the text, the transcript arrives right there. If you're just reading, it appends to the end."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/voice-light.webp"
              alt="A note in As Told titled Alaska trip idea, holding a spoken thought that moves between Telugu and English, transcribed in both scripts exactly as it was said."
            />
          }
        >
          <p className={styles.para}>
            There is no separate voice-note library and no transcript screen to visit. What comes
            back is ordinary, editable text — restructure it, add to it, or type straight over it.
          </p>
        </ProductSplit>
      </Section>

      <Section>
        <SectionIntro
          eyebrow="Spoken structure"
          title="Say it, and it takes shape."
          lede="A clear, standalone command turns the next thing you say into a heading, a list, or a checklist."
        />
        <div className="reveal">
          <ExampleGrid>
            <VoiceExample said="Heading. Alaska trip.">
              <ResultHeading>Alaska trip</ResultHeading>
            </VoiceExample>
            <VoiceExample said="Subheading. Where to stay.">
              <ResultHeading>Where to stay</ResultHeading>
            </VoiceExample>
            <VoiceExample said="Bullet list. Anchorage. Next item. Seward.">
              <ResultBullets items={['Anchorage', 'Seward']} />
            </VoiceExample>
            <VoiceExample said="Checklist. Call Ravi. Next item. Buy groceries.">
              <ResultChecklist items={['Call Ravi', 'Buy groceries']} />
            </VoiceExample>
            <VoiceExample said="End list.">
              <ResultText>Back to prose.</ResultText>
            </VoiceExample>
            <VoiceExample said="My checklist is getting too long.">
              <ResultText>My checklist is getting too long.</ResultText>
            </VoiceExample>
          </ExampleGrid>
          <p className={`${styles.para} ${styles.note}`}>
            Only an isolated command counts. A missed command is recoverable; a phantom one rewrites
            your note.
          </p>
        </div>
      </Section>

      <Section tone="warm">
        <div className={`reveal ${styles.fidelity}`}>
          <div>
            <span className="eyebrow">Fidelity</span>
            <h2>Punctuation, not rewriting.</h2>
            <p className={`lede ${styles.para}`}>
              Speech has sentences and pauses; writing shows them with punctuation and paragraph
              breaks. As Told adds that layer, and stops there.
            </p>
            <FidelityPromises />
            <p className={styles.para}>
              Your slang, your names, your repetitions and your filler words stay in. The rule the
              whole feature is built on: preserve the words, format the speech.
            </p>
          </div>
          <FidelityBoundary />
        </div>
      </Section>

      <Section>
        <SectionIntro
          align="center"
          eyebrow="Languages"
          title="English, Telugu, Hindi — and the mix."
          lede="Real speech switches language mid-clause, so As Told is built for code-switching and keeps each language in its own script."
        >
          <LanguageChips />
          <Link className={`textlink ${styles.afterLink}`} href="/languages">
            See multilingual voice →
          </Link>
        </SectionIntro>
      </Section>

      <Section tone="warm">
        <ProductSplit
          eyebrow="What happens to the recording"
          title="You're asked before anything is sent."
          lede="Transcription needs more computing power than a phone should spend, so the recording goes over an encrypted connection to OpenAI, comes back as text, and is not kept."
          media={
            <PhoneShot
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
          <Link className="textlink" href="/privacy">
            Read the full privacy detail →
          </Link>
        </ProductSplit>
      </Section>

      <FinalCTA title="Say it however it comes." />
    </>
  );
}
