import Link from 'next/link';
import { FAQ, type FaqItem } from '@/components/FAQ';
import { PageHero } from '@/components/PageHero';
import { Section } from '@/components/Section';
import { SupportContact } from '@/components/SupportContact';
import { pageMetadata } from '@/lib/site';

export const metadata = pageMetadata({
  title: 'Support',
  description:
    'Help with As Told: the writing toolbar, pasting from other apps, code blocks and tables, speaking a note, multilingual voice, sharing, finding older notes and the calendar, where notes are stored, Face ID, and Light / Dark.',
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
      <>
        <p>
          Six shapes on the toolbar: Paragraph, Heading, Subheading, Bulleted list, Numbered list,
          and Checklist. Three more arrive with your text rather than from a button —{' '}
          <strong>links</strong>, <strong>tables</strong> and <strong>code blocks</strong> — because
          those are things you paste or type, not styles you apply.
        </p>
        <p>
          That is the whole vocabulary. There is deliberately no bold, italic, underline, colour,
          highlight, font or alignment control. A note is meant to stay a note.
        </p>
      </>
    ),
  },
  {
    q: 'How do lists and checklists work?',
    a: (
      <>
        <p>
          Tap the list button, or type the marker at the start of a line — <code>-</code> for a
          bullet, <code>1.</code> for a numbered item, <code>- [ ]</code> for a checklist item.
          Return carries the list onto the next line, and Return on an empty item ends the list and
          puts you back in ordinary prose.
        </p>
        <p>
          Numbering continues by itself as you press Return, and applying Numbered list to several
          lines at once numbers them in order. A checklist item has a circle beside it — tap the
          circle to tick it, and ticked items stay where you put them rather than being sorted to
          the bottom.
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
    q: 'What happens when I paste code?',
    a: (
      <>
        <p>
          It stays code. A fenced block is drawn as a card — monospaced, indented exactly as it was
          written, syntax-coloured, with the language named and <strong>Copy Code</strong> in the
          corner. Long lines scroll sideways instead of wrapping.
        </p>
        <p>
          If a plain-text paste is obviously code, As Told will recognise it and fence it for you.
          When it isn&rsquo;t certain the text is left exactly as it arrived, and{' '}
          <strong>Paste as Code</strong> is there when you want it anyway. Aligned text — a
          directory tree, an ASCII diagram — is kept as a plain-text block so its columns stay lined
          up.
        </p>
        <p>
          As Told does not run, compile, lint, or complete code. It just refuses to destroy it.
        </p>
      </>
    ),
  },
  {
    q: 'Do links still work?',
    a: (
      <p>
        Yes. A web address you type or paste stays tappable, and a link you copied with its own
        wording keeps that wording. There is no link button, no URL sheet, and no link previews —
        editing a link means editing its text, like every other line. Copying a note out again keeps
        both the words and the destination.
      </p>
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
    q: 'Can I start a note just by speaking?',
    a: (
      <p>
        Yes. Tap the microphone in the header on Home and As Told starts listening straight away —
        no blank note first, no keyboard rising. When you tap Done, the transcript arrives as an
        ordinary note. Cancel, silence, or a failure leave your timeline exactly as it was, because
        no note is created until there are words to put in one.
      </p>
    ),
  },
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
        alone — a missed command is recoverable, a phantom one rewrites your note.{' '}
        <Link className="textlink" href="/voice">
          See how voice works →
        </Link>
      </p>
    ),
  },
  {
    /* The one place on the site where the benchmark groups are named.
       They are release test groups, not a supported-language list, and putting
       them anywhere a visitor meets first — hero copy, a chip row, a screenshot
       caption — turns measured evidence into a product boundary
       (`RULES.md` §7, "Language claims"). */
    q: 'Which languages can I speak?',
    a: (
      <>
        <p>
          As Told does not ask you to choose a language before recording. Voice transcription is
          designed for multilingual speech and code-switching: speak in one language, switch
          mid-sentence, or mix them the way you normally do, and each language comes back in its
          own script rather than being translated. Accuracy does vary by language, accent,
          recording conditions, and how much the languages are mixed.
        </p>
        <p>
          Before each release, As Told is measured against a set of representative single-language
          and mixed-language flows — currently <strong>English</strong>, <strong>Telugu</strong>,{' '}
          <strong>Hindi</strong>, <strong>English + Telugu</strong> and{' '}
          <strong>English + Hindi</strong>. Those are quality benchmarks, not the only languages
          you can speak.{' '}
          <Link className="textlink" href="/languages">
            See multilingual voice →
          </Link>
        </p>
      </>
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
    q: 'Can I pause a recording?',
    a: (
      <p>
        Yes. Tap <strong>Pause</strong>, take as long as you need, then <strong>Resume</strong> —
        it stays one continuous recording, and only the time you were actually speaking counts
        towards the five-minute limit. A call, Siri, leaving the note, or the app going to the
        background all finish the recording and transcribe it rather than throwing it away.
      </p>
    ),
  },
  {
    q: 'What happens if transcription fails?',
    a: (
      <>
        <p>
          As Told keeps that recording on your iPhone and offers <strong>Retry</strong> or{' '}
          <strong>Delete Recording</strong>, so a dropped connection is not how a thought gets
          lost. If the app closes before you answer, you are offered it once more the next time you
          open As Told.
        </p>
        <p>
          Nothing is uploaded in the background while it waits, and there is still no recordings
          library. The recording is removed as soon as a transcript arrives, as soon as you delete
          it, and in any case within 24 hours.
        </p>
      </>
    ),
  },
  {
    q: 'Will I be warned before my recording is sent?',
    a: (
      <p>
        Yes. The first time you finish a recording, As Told explains that the audio goes to OpenAI
        to be turned into text and that nothing else from your note is sent — then waits for you to
        continue or cancel. You answer once and it doesn&rsquo;t ask again.{' '}
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

const SHARING: readonly FaqItem[] = [
  {
    q: 'How do I send a note to someone?',
    a: (
      <p>
        Open the note and tap <strong>Share</strong> in the top-right corner. The iPhone&rsquo;s own
        share sheet appears, so a note can go to whichever apps and services are already available
        on your device. As Told adds no destination picker of its own.
      </p>
    ),
  },
  {
    q: 'Does the formatting survive?',
    a: (
      <p>
        Where the destination can take it, yes: headings, lists, checklists, tables, links and code
        arrive as themselves. Somewhere that only accepts plain text gets plain text, with links
        written out so the destination isn&rsquo;t lost. Sharing never changes the note you shared.
      </p>
    ),
  },
  {
    q: 'Does sharing upload my note anywhere?',
    a: (
      <p>
        No. There is no As Told link, nothing hosted, and no record kept of what you shared or where
        it went. The note is handed to the sheet, and where it goes from there is between you and
        the app you chose.
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

/* Home stopped being the whole archive on 2026-08-31 — it shows the recent
   periods and the rest is one tap away — and that is exactly the kind of change
   that reads as "my notes are gone" to someone who did not read release notes. */
const FINDING: readonly FaqItem[] = [
  {
    q: 'Why does Home only show recent notes?',
    a: (
      <>
        <p>
          Home is the recent library: <strong>Today</strong>, then the{' '}
          <strong>Previous 7 Days</strong>. Each group shows its first few notes, with{' '}
          <strong>Show all</strong> underneath when there are more. Nothing is deleted or hidden
          for good — anything older is one tap away under <strong>Browse older notes</strong> at
          the bottom of Home, which opens the complete timeline.
        </p>
        <p>
          That link appears only when something is actually older than a week. If you don&rsquo;t
          see it, Home is already showing everything you have.
        </p>
      </>
    ),
  },
  {
    q: 'How does the calendar work?',
    a: (
      <p>
        Tap the calendar in Home&rsquo;s header. A dot under a day means you wrote something that
        day, and a busier day shows up to three. Tap a day and its notes are listed right under the
        month; it opens on today. Use it when you remember <em>when</em> you wrote something, and
        search when you remember a word from it.
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
          <FAQ title="Sharing a note" items={SHARING} />
          <FAQ title="Finding a note again" items={FINDING} />
          <FAQ title="Privacy & storage" items={PRIVACY} />
          <FAQ title="If something goes wrong" items={RECOVERY} />
        </div>
        <SupportContact heading="Still need a hand?" here />
      </Section>
    </>
  );
}
