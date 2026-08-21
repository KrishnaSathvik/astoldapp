import { FinalCTA } from '@/components/FinalCTA';
import { En } from '@/components/LanguageExample';
import { LanguageSwitcher, type LanguageSample } from '@/components/LanguageSwitcher';
import { PageHero } from '@/components/PageHero';
import { PhoneShot } from '@/components/PhoneShot';
import { ProductSplit } from '@/components/ProductSplit';
import { Section, SectionIntro } from '@/components/Section';
import { pageMetadata } from '@/lib/site';
import styles from './page.module.css';

export const metadata = pageMetadata({
  title: 'Multilingual voice notes — Telugu, Hindi & English',
  description:
    'As Told captures the way you actually speak: Telugu, Hindi, English, and the natural mix between them — kept in the script you spoke, never translated.',
  path: '/languages',
});

const SAMPLES: readonly LanguageSample[] = [
  {
    id: 'te',
    label: 'Telugu',
    lang: 'te',
    sentence:
      'రేపు అమ్మకి ఫోన్ చేయాలి. చాలా రోజులైంది సరిగ్గా మాట్లాడి. సాయంత్రం పని అయిపోయాక మర్చిపోకుండా చేయాలి.',
    caption: 'A normal thought, written back in Telugu — not converted into Roman letters.',
  },
  {
    id: 'hi',
    label: 'Hindi',
    lang: 'hi',
    sentence:
      'कल पापा को फोन करना है। पिछले दो दिनों से सोच रहा हूँ और हर बार भूल जा रहा हूँ। शाम को काम खत्म होते ही करूँगा।',
    caption: 'Hindi stays in Devanagari, the way you said it.',
  },
  {
    id: 'te-en',
    label: 'Telugu + English',
    lang: 'te',
    sentence: (
      <>
        రేపు <En>office</En> కి కొంచెం <En>early</En> గా వెళ్లాలి. 10:30కి <En>client call</En>{' '}
        ఉంది. దాని ముందు <En>deck</En> ఒక్కసారి <En>check</En> చేసి <En>final numbers update</En>{' '}
        చేయాలి.
      </>
    ),
    caption:
      'No need to choose a language first. Telugu and English can live in the same thought naturally.',
  },
  {
    id: 'hi-en',
    label: 'Hindi + English',
    lang: 'hi',
    sentence: (
      <>
        इस <En>weekend</En> घर जाने का <En>plan</En> है, <En>but</En> <En>Saturday meeting</En> हुई
        तो <En>Sunday morning</En> निकलूँगा. <En>Tickets</En> अभी तक <En>book</En> नहीं की.
      </>
    ),
    caption:
      'Switch mid-sentence if that is how the thought comes out. As Told keeps the mix instead of forcing everything into one language.',
  },
  {
    id: 'en',
    label: 'English',
    lang: 'en',
    sentence:
      'Okay, reminder for tomorrow — call the bank first, then, um… actually, do the insurance call after that. Yeah. Bank first.',
    caption:
      'The pauses and the change of mind stay part of the thought. As Told adds punctuation so it reads cleanly; it does not rewrite what you meant.',
  },
];

const MAY_ADD = ['Punctuation', 'Capitalization', 'Sentence boundaries', 'Clear paragraph breaks'];

const NEVER = [
  'Correct your grammar',
  'Paraphrase your sentences',
  'Summarize your thought',
  'Translate what you said',
  'Make casual speech more formal',
];

export default function LanguagesPage() {
  return (
    <>
      <PageHero
        eyebrow="Multilingual"
        title="Speak the way you actually speak."
        lede="Telugu. Hindi. English. Or all three moving through the same thought. As Told keeps each language in its own script and puts the words back into the note where you were writing."
      />

      {/* Live examples */}
      <Section flush>
        <div className="reveal">
          <LanguageSwitcher samples={SAMPLES} />
          <p className={styles.closing}>Five ways of speaking. One note.</p>
        </div>
      </Section>

      {/* In the note */}
      <Section tone="warm">
        <ProductSplit
          reverse
          mediaLed
          eyebrow="In the note"
          title="Your voice lands where your cursor is."
          lede="Start typing. Stop halfway through. Tap the mic and say the rest — your words appear right where you left off, as ordinary, editable text."
          media={
            <PhoneShot
              size="lg"
              src="/assets/shots/voice-light.webp"
              alt="A note in As Told titled Alaska trip idea: the typed title, then a spoken paragraph transcribed verbatim, moving between Telugu and English exactly as it was said."
            />
          }
        >
          {/* This pair is the note in the screenshot beside it, word for word —
              the title that was typed and the paragraph that was spoken. It read
              as a contradiction when the copy said Hyderabad and the capture
              said Alaska. Change one, change the other. */}
          <div className={styles.handoff}>
            <p className={styles.handoffStep}>
              <span className={styles.handoffTag}>Typed</span>
              Alaska trip idea
            </p>
            <p className={styles.handoffStep} lang="te">
              <span className={styles.handoffTag}>Then spoken</span>
              నాకు <En>Alaska trip</En> గురించి ఒక <En>idea</En> వచ్చింది. <En>Maybe</En> మనం{' '}
              <En>Anchorage</En> లో <En>whole week stay</En> చేయకుండా, <En>Seward</En> లో{' '}
              <En>two nights stay</En> చేస్తే <En>better</En> ఉంటుంది.
            </p>
          </div>
          <p className={styles.para}>
            No separate transcript screen, no voice-note inbox, no second place to manage what you
            said. It is still one note.
          </p>
        </ProductSplit>
      </Section>

      {/* The mix stays the mix */}
      <Section>
        <SectionIntro
          eyebrow="Fidelity"
          title="The mix stays the mix."
          lede="If you say something in Telugu, it should not quietly come back in English. And if you switch to English for three words and then back, those three words are not a reason to rewrite the sentence."
        />
        <div className={`reveal ${styles.mix}`}>
          <div className={styles.mixKept}>
            <span className={styles.mixTag}>What you said</span>
            <p lang="te">
              రేపు <En>office</En> కి రావడం కుదరదు. <En>Maybe afternoon call</En> లో{' '}
              <En>join</En> అవుతాను.
            </p>
          </div>
          <div className={styles.mixRefused}>
            <span className={styles.mixTag}>Not this</span>
            <p lang="en">
              I won&rsquo;t be able to come to the office tomorrow. Maybe I&rsquo;ll join the
              afternoon call.
            </p>
          </div>
        </div>
        <p className={`reveal ${styles.mixNote}`}>
          The second version carries roughly the same meaning. <strong>But it isn&rsquo;t what you
          said.</strong>
        </p>
      </Section>

      {/* Punctuation, not polishing */}
      <Section tone="warm">
        <SectionIntro
          title="Punctuation, not polishing."
          lede="Speech needs a little structure when it becomes text. As Told supplies that much and stops."
        />
        <div className={`reveal ${styles.rules}`}>
          <div>
            <h3 className={styles.rulesHead}>It may add</h3>
            <ul className={styles.rulesList}>
              {MAY_ADD.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </div>
          <div>
            <h3 className={styles.rulesHead}>It does not</h3>
            <ul className={`${styles.rulesList} ${styles.rulesNever}`}>
              {NEVER.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </div>
        </div>
        <div className={`reveal ${styles.aside}`}>
          <p lang="hi" className={styles.asideSaid}>
            यार आज बिल्कुल <En>mood</En> नहीं है.
          </p>
          <p className={styles.asideNot}>
            The goal is not &ldquo;I don&rsquo;t feel like doing anything today.&rdquo; The goal is
            to keep your sentence.
          </p>
        </div>
      </Section>

      <FinalCTA title="Say it however it comes." />
    </>
  );
}
