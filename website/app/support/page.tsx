import Link from 'next/link';
import { FAQ, type FaqItem } from '@/components/FAQ';
import { PageHero } from '@/components/PageHero';
import { Section } from '@/components/Section';
import { SupportContact } from '@/components/SupportContact';
import { pageMetadata } from '@/lib/site';

export const metadata = pageMetadata({
  title: 'Support',
  description:
    'Help with As Told: structure and the writing toolbar, pasting from other apps, adding text by voice, supported languages, where notes are stored, Face ID, and Light / Dark.',
  path: '/support',
});

/* Every answer below states behaviour that exists in the shipping app. If a
   question can only be answered with "it depends" or "later", it is not here. */

const WRITING: readonly FaqItem[] = [
  {
    q: 'How do I format a note?',
    a: (
      <>
        <p>
          There is a writing toolbar just above the keyboard whenever the cursor is in the body of a
          note. <strong>Aa</strong> opens Heading, Subheading and Paragraph; next to it are one-tap
          buttons for a bulleted list, a numbered list and a checklist. The button for the shape
          your cursor is already in is highlighted.
        </p>
        <p>
          That toolbar is As Told&rsquo;s own — it is not a row added to Apple&rsquo;s keyboard, and
          it appears only while you are writing. <strong>Aa</strong> also holds{' '}
          <strong>Writing help</strong>, a short reference to every shape and the shortcut for it.
        </p>
      </>
    ),
  },
  {
    q: 'What formatting does As Told have?',
    a: (
      <p>
        Six structures: Paragraph, Heading, Subheading, Bulleted list, Numbered list, and Checklist.
        That is the whole vocabulary — there is deliberately no bold, italic, underline, colour,
        highlight, font or alignment control. A note is meant to stay a note.
      </p>
    ),
  },
  {
    q: 'How do lists and checklists work?',
    a: (
      <>
        <p>
          Tap the list button, or type the marker at the start of a line — <code>-</code> for a
          bullet, <code>1.</code> for a numbered item, <code>- [ ]</code> for a checkbox. Return
          carries the list onto the next line, and Return on an empty item ends the list and puts
          you back in ordinary prose.
        </p>
        <p>
          Numbering continues by itself as you press Return, and applying Numbered list to several
          lines at once numbers them in order. Tap a checkbox to tick it; ticked items stay where
          you put them rather than being sorted to the bottom.
        </p>
      </>
    ),
  },
];

const PASTE: readonly FaqItem[] = [
  {
    q: 'Can I paste content from ChatGPT or Claude?',
    a: (
      <>
        <p>
          Yes — and from a browser, a document, an email, or another notes app. When you copy from
          an app that describes its formatting to the clipboard, As Told reads that description and
          keeps every structure it has: headings, subheadings, paragraph breaks, bulleted and
          numbered lists, checklists, and tables.
        </p>
        <p>
          This is clipboard compatibility, not an integration. As Told is not connected to ChatGPT,
          Claude, or any account of yours — it never sees anything beyond the text you copied.
        </p>
      </>
    ),
  },
  {
    q: 'What formatting does As Told preserve when I paste?',
    a: (
      <>
        <p>
          Exactly the structures listed above, and nothing else — because those are the only shapes
          a note has. Pasting cannot add formatting the editor does not otherwise have.
        </p>
        <p>
          If the clipboard carries only plain text, it is pasted precisely as it arrived and nothing
          is inferred from it. A short line is not promoted to a heading because it looks like one;
          guessing would be rewriting your note.
        </p>
      </>
    ),
  },
  {
    q: 'Can I paste tables?',
    a: (
      <>
        <p>
          Yes. A pasted table is kept as a table and drawn as a grid while you read the note. Tap it
          and it opens full-screen, so a table too wide for a phone can still be scanned column by
          column.
        </p>
        <p>
          As Told has no table editor: you cannot create one from a toolbar, add a row, or sort a
          column. When you tap into the note to edit it, the table shows as the plain rows it is
          actually stored as — ordinary text you can change like any other line.
        </p>
      </>
    ),
  },
  {
    q: 'Why did bold or italic styling disappear when I pasted?',
    a: (
      <p>
        Because As Told has nowhere to put it. Bold, italic, colours, fonts, and page layout are
        inline styling rather than structure, and the editor has none of it by design. Those parts
        simplify to plain text on the way in.{' '}
        <strong>Your words themselves are never changed</strong> — nothing is reworded, reordered,
        or removed.
      </p>
    ),
  },
];

const VOICE: readonly FaqItem[] = [
  {
    q: 'How do I add text by voice?',
    a: (
      <p>
        Open a note and tap the microphone at the end of the writing toolbar. Speak normally, then
        tap Done. As Told transcribes what you said and puts it into the note as ordinary, editable
        text.
      </p>
    ),
  },
  {
    q: 'Where does dictated text appear?',
    a: (
      <p>
        Wherever the cursor is. Put it mid-paragraph and the transcript lands there; if you were
        just reading the note rather than typing in it, the text is added to the end. There is no
        separate voice-note library and no transcript screen to visit afterwards.
      </p>
    ),
  },
  {
    q: 'Can I speak headings and lists?',
    a: (
      <p>
        Yes. A clear, standalone command — &ldquo;Heading&rdquo;, &ldquo;Subheading&rdquo;,
        &ldquo;Bullet list&rdquo;, &ldquo;Checklist&rdquo;, &ldquo;Next item&rdquo;, &ldquo;New
        paragraph&rdquo;, &ldquo;End list&rdquo; — shapes what you say next. Ordinary speech that
        merely mentions one of those words (&ldquo;my checklist is getting too long&rdquo;) is left
        alone.{' '}
        <Link className="textlink" href="/voice">
          See the full list →
        </Link>
      </p>
    ),
  },
  {
    q: 'Which languages are supported?',
    a: (
      <p>
        English, Telugu, and Hindi — plus the natural mix between them, like Telugu + English or
        Hindi + English. You can switch languages mid-sentence, and each language comes back in its
        own script.{' '}
        <Link className="textlink" href="/languages">
          See multilingual voice →
        </Link>
      </p>
    ),
  },
  {
    q: 'Does As Told rewrite what I say?',
    a: (
      <p>
        No. It adds punctuation, capitalization and paragraph breaks so a spoken thought reads like
        written language, and stops there. It does not translate, summarize, paraphrase, polish, or
        grammar-correct. Your slang, your names, your repetitions and your filler words stay in.
      </p>
    ),
  },
  {
    q: 'Will I be warned before my recording is sent?',
    a: (
      <p>
        Yes. The first time you finish a recording, As Told explains that the audio goes to OpenAI
        to be turned into text, that nothing else from your note is sent, and that the recording
        isn&rsquo;t kept — then waits for you to continue or cancel. You answer once and it
        doesn&rsquo;t ask again.{' '}
        <Link className="textlink" href="/privacy">
          Read the full privacy detail →
        </Link>
      </p>
    ),
  },
  {
    q: 'Why does voice need an internet connection?',
    a: (
      <p>
        Typing, editing, browsing, search, and the calendar all work offline. Only the transcription
        step needs a connection, because the audio is sent securely to be turned into text. If
        you&rsquo;re offline when you finish a recording, As Told won&rsquo;t lose it silently —
        you&rsquo;ll get a clear option to retry or discard.
      </p>
    ),
  },
  {
    q: 'How long can one recording be?',
    a: (
      <p>
        Up to five minutes, which is roughly seven or eight hundred spoken words. If you reach it,
        As Told finishes the recording and transcribes it rather than throwing it away &mdash; tap
        the microphone again to keep going, and the next transcription lands wherever your cursor
        is. Voice is for speaking a thought into a note, not for recording a meeting.
      </p>
    ),
  },
  {
    q: 'Is there a limit on voice transcription?',
    a: (
      <p>
        As Told includes up to 60 minutes of voice transcription each month. Most people
        won&rsquo;t need to think about it. If you reach the limit, As Told will tell you when
        voice becomes available again, and everything else &mdash; typing, editing, search, the
        calendar &mdash; keeps working normally.
      </p>
    ),
  },
];

const PRIVACY: readonly FaqItem[] = [
  {
    q: 'Do I need an account?',
    a: (
      <p>
        No. Open the app and start writing. There is no sign-up, email, or password — and therefore
        nothing tying your notes to an identity.
      </p>
    ),
  },
  {
    q: 'Where are my notes stored?',
    a: (
      <p>
        Locally, in the app&rsquo;s own storage on your iPhone. Search and the calendar run against
        your own device, which is why they work without a connection.
      </p>
    ),
  },
  {
    q: 'Is there cloud sync or a backup?',
    a: (
      <p>
        Not in this version. There is no cloud copy of your notes and no device-to-device sync.
        Deleting As Told deletes its local notes; offloading the app instead, from iPhone Storage
        in Settings, keeps them. A device backup or transfer may restore them later, depending on
        your Apple backup settings.
      </p>
    ),
  },
  {
    q: 'How does the Face ID lock work?',
    a: (
      <p>
        Go to Profile → Settings and turn on <strong>Lock with Face ID</strong>. It is off unless
        you turn it on. When it&rsquo;s on, your notes are covered before iOS takes its app-switcher
        snapshot and revealed only after you authenticate; your device passcode works as a fallback.
      </p>
    ),
  },
  {
    q: 'How do I switch between Light and Dark?',
    a: (
      <p>
        Go to Profile → Settings → <strong>Theme</strong> and choose Light, Dark, or Use device
        settings. &ldquo;Use device settings&rdquo; follows your iPhone automatically.
      </p>
    ),
  },
];

const RECOVERY: readonly FaqItem[] = [
  {
    q: 'I deleted a note by accident. Can I get it back?',
    a: (
      <p>
        Right after you swipe to delete, an <strong>Undo</strong> appears for a few seconds — tap it
        and the note comes back exactly as it was. Once that window closes the note is gone, and
        because there is no cloud copy there is nowhere else to recover it from. If it matters, it
        is worth having a device backup.
      </p>
    ),
  },
];

export default function SupportPage() {
  return (
    <>
      <PageHero
        width="faq"
        eyebrow="Help"
        title="Help when you need it."
        lede="As Told is meant to stay out of your way, so there isn't much to learn. Here are the questions people ask most."
      />

      {/* An FAQ list is too airy at feature width and too cramped in a reading
          column, so this is the one page that uses the 900px measure. */}
      <Section width="faq" tight flush>
        <div className="reveal">
          <FAQ title="Writing" items={WRITING} openFirst />
          <FAQ title="Pasting from other apps" items={PASTE} />
          <FAQ title="Voice" items={VOICE} />
          <FAQ title="Privacy & storage" items={PRIVACY} />
          <FAQ title="If something goes wrong" items={RECOVERY} />
        </div>
        <SupportContact heading="Still need a hand?" here />
      </Section>
    </>
  );
}
