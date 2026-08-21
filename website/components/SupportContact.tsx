import Link from 'next/link';
import { SUPPORT_EMAIL } from '@/lib/site';
import { ContactBlock } from './Prose';

type Props = {
  heading: string;
  /** Set on `/support` itself, where "the questions on the support page" is this page. */
  here?: boolean;
};

/**
 * The one place the site talks about being contacted — used by Support, Privacy
 * and Terms so there is a single answer to change.
 *
 * While `SUPPORT_EMAIL` is null there is genuinely nowhere to write, and the
 * honest version of that is to point at the two places that *do* answer
 * immediately rather than to describe a channel that does not exist. The line
 * this replaced — "use the support contact provided with As Told on the App
 * Store listing" — sent a reader who was already here somewhere else to be told
 * to come back.
 */
export function SupportContact({ heading, here = false }: Props) {
  return (
    <ContactBlock>
      <h3>{heading}</h3>
      {SUPPORT_EMAIL ? (
        <p>
          Write to{' '}
          <a className="textlink" href={`mailto:${SUPPORT_EMAIL}`}>
            {SUPPORT_EMAIL}
          </a>{' '}
          and a person will read it.
        </p>
      ) : (
        <p>
          There is no support queue to wait in, and two places that answer straight away:{' '}
          {here ? (
            'the questions above'
          ) : (
            <Link className="textlink" href="/support">
              the questions on Support
            </Link>
          )}
          , and the app&rsquo;s own reference — tap <strong>Aa</strong> in the writing toolbar and
          choose <strong>Writing help</strong>. If neither covers it, that is a gap in this page.
        </p>
      )}
    </ContactBlock>
  );
}
