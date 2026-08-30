import { DocLayout, type TocItem } from '@/components/DocLayout';
import { Prose, ShortVersion } from '@/components/Prose';
import { SupportContact } from '@/components/SupportContact';
import { pageMetadata } from '@/lib/site';

export const metadata = pageMetadata({
  title: 'Privacy',
  description:
    'How As Told protects your notes: no account, local-first storage, faithful voice transcription that is not kept, and optional Face ID.',
  path: '/privacy',
});


/**
 * Quiet anchor navigation, desktop only. The labels are shorter than the
 * headings on purpose — this is a place-marker, not a second table of contents
 * competing with the document.
 */
const TOC: readonly TocItem[] = [
  { id: 'short-version', label: 'Short version' },
  { id: 'notes', label: 'Where notes live' },
  { id: 'voice', label: 'Voice & transcription' },
  { id: 'face-id', label: 'Face ID' },
  { id: 'settings', label: 'Name & settings' },
  { id: 'analytics', label: 'Ads & analytics' },
  { id: 'children', label: 'Children' },
  { id: 'changes', label: 'Changes' },
];

export default function PrivacyPage() {
  return (
    <DocLayout
      eyebrow="Private by design"
      title="Your writing stays yours."
      lede="No sign-up, no cloud library of your writing, and voice that is transcribed faithfully and not kept. This page explains exactly what that means."
      updated="August 2026"
      toc={TOC}
    >
      <Prose>
        <ShortVersion>
          <h2 id="short-version">The short version</h2>
          <ul>
            <li>
              <strong>No account.</strong> There&rsquo;s no sign-up, email, or password to write
              something down.
            </li>
            <li>
              <strong>Your notes stay on your device.</strong> They&rsquo;re stored locally on
              your iPhone. There is no cloud copy and no sync, so deleting the app deletes them
              with it.
            </li>
            <li>
              <strong>Voice leaves the device only when you ask.</strong> A recording is sent for
              transcription only when you choose to transcribe it, and only after you agree the
              first time.
            </li>
            <li>
              <strong>OpenAI does the transcription.</strong> As Told sends the recording through
              its own transcription service to OpenAI. Nothing else from your note goes with it.
            </li>
            <li>
              <strong>The recording is deleted once the words come back.</strong> If transcription
              fails on a dropped connection, As Told can keep that one recording on your iPhone so
              you can retry it — and removes it within 24 hours either way.
            </li>
            <li>
              <strong>Your content isn&rsquo;t logged.</strong> No audio, transcript, note text,
              or search query is written to As Told&rsquo;s logs. Ordinary connection information
              is handled by the service that hosts it.
            </li>
            <li>
              <strong>Optional Face ID.</strong> Lock the app, and your notes are covered in the
              app switcher until you unlock.
            </li>
          </ul>
        </ShortVersion>

        <h2 id="notes">Where your notes live</h2>
        <p>
          Your note library is kept locally, in the app&rsquo;s own storage on your iPhone. As
          Told doesn&rsquo;t require an account and doesn&rsquo;t sync your notes to a server you
          don&rsquo;t control. Because there&rsquo;s no account, there is nothing tying your notes
          to an identity.
        </p>
        <p>
          Search and the calendar run against your own device, which is also why they stay fast
          and work without a connection. In this version there is no built-in sync or backup
          service, and As Told does not keep a separate cloud copy of your notes.
        </p>
        <p>
          Keeping your notes on the device also means iOS controls their lifetime. If you delete As
          Told, iOS deletes the app&rsquo;s local data — and the notes in it — along with the app,
          and As Told has no copy elsewhere to restore them from.
        </p>
        <p>
          Offloading the app instead of deleting it, from iPhone Storage in Settings, keeps that
          data in place. Whether a device backup or a transfer to a new iPhone brings your notes
          back depends on your own Apple backup settings.
        </p>
        <p>
          If a future version adds optional device-to-device sync, it will be exactly that —{' '}
          <strong>optional</strong>, clearly explained, and off unless you turn it on.
        </p>

        <h2 id="voice">Voice &amp; transcription</h2>
        <p>
          Plenty of apps say &ldquo;nothing ever leaves your device&rdquo; and quietly mean
          &ldquo;except this.&rdquo; Voice is the one place where something does, so the rest of
          this section says exactly what, when, and for how long.
        </p>

        <h3 id="voice-leaves">What leaves your iPhone</h3>
        <p>
          Recording a voice note keeps the audio on your iPhone. It leaves the device only when you
          choose to transcribe it — and the first time that would happen, As Told tells you and
          waits for your answer. If you decline, the recording is deleted and nothing is sent.
        </p>
        <p>
          When you continue, As Told sends that recording securely to <strong>OpenAI</strong>,
          through the As Told transcription service, for one purpose: turning your speech into
          text.
        </p>
        <p>
          <strong>
            No title, existing note text, search history, or other note content is included.
          </strong>{' '}
          The service receives the recording, a fixed set of transcription instructions, and
          allowed-language hints, and nothing else.
        </p>

        <h3 id="voice-local">What stays local</h3>
        <p>
          The recording on your iPhone is deleted once the transcript arrives. As Told does not
          keep the recording or the transcript on its side after the request finishes.
        </p>
        <p>
          OpenAI&rsquo;s API documentation states that its audio transcription endpoint does not
          retain customer content for abuse monitoring or application state.
        </p>

        <h3 id="voice-retry">Recordings kept for a retry</h3>
        <p>
          If transcription fails for a reason worth trying again — no connection, a request that
          timed out, the service briefly unavailable — As Told keeps that recording in its own
          temporary storage on your iPhone and offers you <strong>Retry</strong> or{' '}
          <strong>Delete Recording</strong>.
        </p>
        <p>
          Nothing is sent while it waits, and nothing is uploaded in the background. A failure that
          retrying cannot fix, such as a recording with no speech in it, keeps nothing at all.
        </p>

        <h3 id="voice-24h">How long temporary audio remains</h3>
        <p>
          A recording kept for a retry is removed as soon as a transcript arrives, as soon as you
          delete it, and in any case within <strong>24 hours</strong> — whether you come back to it
          or not.
        </p>

        <h3 id="voice-logs">What is written down</h3>
        <p>
          As Told&rsquo;s transcription service logs only technical metadata needed to run
          reliably: a request identifier, the response status, how long it took, the model used,
          and the size and length of the audio.
        </p>
        <p>
          It does not log your audio, your transcript, your note title, your note text, or your
          search queries. The infrastructure that hosts the service handles ordinary connection
          information, such as an IP address, to keep it available and to prevent abuse.
        </p>
        <p>
          Transcription requests are also checked with Apple&rsquo;s App Attest, to confirm they
          come from a genuine copy of As Told. That check identifies the app, not you, and is not
          linked to your notes.
        </p>

        <h3 id="voice-allowance">The fair-use counter</h3>
        <p>
          Voice transcription is free and costs As Told money to run, so each installation includes
          up to 60 minutes of transcription a month. Counting that is the one thing the
          transcription service keeps between requests: a scrambled, one-way form of the
          App&nbsp;Attest installation identifier, the current calendar month, and a number of
          seconds.
        </p>
        <p>
          That is the whole record. It holds no audio, no transcript, no note text, no name, and no
          email, and it cannot be traced back to you or to anything you wrote &mdash; it is a
          duration, not a history of what you said. If you reach the limit, As Told tells you when
          voice becomes available again; everything else in the app keeps working.
        </p>

        <h3 id="voice-words">Your words, unchanged</h3>
        <p>
          Your speech is transcribed <strong>in your own words</strong>. Natural punctuation,
          capitalization, and paragraph breaks are added so a spoken thought reads like written
          language — but As Told does not translate, summarize, rewrite, polish, or grammar-correct
          what you said.
        </p>
        <p>
          The transcript is meant to be what you actually spoke — in whichever language or mix of
          languages you spoke it — inserted directly into your note as ordinary, editable text.
        </p>

        <h2 id="face-id">Face ID &amp; the app switcher</h2>
        <p>
          You can optionally require Face ID (or your device passcode) to open As Told. It is off
          unless you turn it on. Authentication is handled by Apple&rsquo;s Local Authentication
          framework — As Told is told whether you succeeded, and never receives your biometric
          data.
        </p>
        <p>
          When the lock is on and the app leaves the screen, your note content is covered before
          iOS takes its app-switcher snapshot, so your writing isn&rsquo;t left visible behind the
          lock.
        </p>

        <h2 id="settings">Your name and settings</h2>
        <p>
          The name on your profile is optional and stored only on your device. It isn&rsquo;t an
          account, it isn&rsquo;t sent anywhere, and you can leave it blank. Your theme choice and
          lock setting are local in the same way.
        </p>

        <h2 id="analytics">Advertising, tracking, and analytics</h2>
        <p>
          As Told carries no advertising and no tracking. There is no analytics SDK in the app,
          and no third-party software development kit of any kind. Nothing you write is used to
          build a profile of you or to target anything at you. If product analytics are ever
          added, they will <strong>never</strong> include your note text, transcript text, audio,
          or search queries.
        </p>

        <h2 id="children">Children</h2>
        <p>
          As Told is a general-audience notes app and isn&rsquo;t directed at children, and it
          doesn&rsquo;t collect personal information to build a profile of anyone.
        </p>

        <h2 id="changes">Changes to this page</h2>
        <p>
          If these practices change, this page and the date at the top are updated. Material
          changes will be reflected before a new version relies on them.
        </p>

        <SupportContact heading="Questions about privacy?" />
      </Prose>
    </DocLayout>
  );
}
