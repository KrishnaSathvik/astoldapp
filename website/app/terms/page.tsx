import Link from 'next/link';
import { DocLayout } from '@/components/DocLayout';
import { Prose } from '@/components/Prose';
import { SupportContact } from '@/components/SupportContact';
import { pageMetadata } from '@/lib/site';

export const metadata = pageMetadata({
  title: 'Terms',
  description:
    'The terms As Told is provided under: you own the notes you create, the app is provided as-is, and your notes live on your device.',
  path: '/terms',
});

export default function TermsPage() {
  return (
    <DocLayout
      eyebrow="Terms"
      title="The short arrangement."
      lede="As Told is a personal note-taking app. These are the terms it is offered under."
      updated="August 2026"
    >
      <Prose>
        <h2>Your notes are yours</h2>
        <p>
          You own everything you write or speak into As Told. Using the app grants no claim over
          your notes, and there is no account under which they could be held.
        </p>

        <h2>Provided as-is</h2>
        <p>
          As Told is provided as-is, for personal note-taking, without warranty. It is not
          intended as a system of record for anything you cannot afford to lose.
        </p>

        <h2>Backups are yours to keep</h2>
        <p>
          Because your notes are stored on your device and are not synced to a server, keeping
          your own device backups is the way to protect against data loss. Deleting the app
          deletes its notes with it.
        </p>

        <h2>Voice transcription</h2>
        <p>
          The one feature that contacts a server is voice transcription, and it does so only after
          you agree. What is sent, what is logged, and what is kept are described on the{' '}
          <Link className="textlink" href="/privacy">
            privacy page
          </Link>
          .
        </p>

        <h2>Changes</h2>
        <p>
          If these terms change, this page and the date at the top are updated. There is no
          separate agreement held anywhere else, and nothing you accepted in the app supersedes
          what is written here — this page is the whole of it.
        </p>

        <SupportContact heading="Questions about these terms?" />
      </Prose>
    </DocLayout>
  );
}
