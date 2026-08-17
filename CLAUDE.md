# CLAUDE.md

Agent operating guide for **[AppName]** — read this first when working in this repo.

## What this repo is

A specification repository (no application code yet) for a premium, **local-first iPhone notes app**
for capturing a thought exactly as it came — by typing or speaking.

- **Tagline:** Write it. Say it. Keep it.
- **Loop:** Open → write or speak → leave.
- **Platform:** iPhone / iOS, SwiftUI + SwiftData, native-first.
- **Voice:** transcription of English, Telugu, Hindi, and Telugu/Hindi ↔ English code-switching,
  captured **verbatim** (no translate / summarize / rewrite / grammar-fix).
- **Not:** an AI notes app, a second brain, a journaling prompt engine, or "Apple Notes with more buttons."
- **Status:** V1 specification, ready to begin implementation.

> **Primary rule:** the note is always more important than the interface.

The app name is intentionally still a placeholder — `[AppName]`. Do not invent or hardcode a final
name; leave the placeholder until the human decides. The design reference
(`docs/design-reference/screens-overview.png`) uses **"Yourly"** with a feather/quill mark as the
visual working name only — treat it as the current logotype, not a committed product name.

## The one rule that matters most

**When in doubt, consult [`RULES.md`](./RULES.md).** It is the single source of truth for what must and
must not happen — locked product constraints, the voice/verbatim contract, privacy & security,
UI/UX, architecture, the do-not-build list, and the release gate. If a request conflicts with a rule
there, surface the conflict instead of silently overriding it.

## Where things live

| File | Use it for |
|---|---|
| `README.md` | Product overview, locked decisions, document map, source-tree sketch |
| `RULES.md` | **Non-negotiable rules — check here for any doubt** |
| `docs/01-product-requirements.md` | Goals, scope, user flows, success criteria, release gate |
| `docs/02-features.md` | Per-feature behavior + acceptance criteria (P0 / P1 / Later) |
| `docs/03-design-system.md` | Screen specs, UX rules, design tokens, accessibility, "Quiet Editorial" |
| `docs/04-voice-transcription.md` | Full voice contract: languages, cursor insertion, errors, benchmark |
| `docs/05-architecture.md` | Modules, `Note` model, `NoteStore`, pagination, backend flow, error model |
| `docs/06-tech-stack.md` | Exact technologies and the reasoning for each |
| `docs/07-build-plan.md` | Phase-by-phase build order and Definition of Done |
| `docs/design-reference/screens-overview.png` | **Canonical 10-screen visual reference** — match it |

## How to work here

1. **Start from the spec.** Before implementing anything, read the owning doc(s) above and the
   relevant section of `RULES.md`. The specs are detailed and opinionated — follow them.
2. **Respect the build order.** Work in vertical slices (`docs/07-build-plan.md`). Prove the typed-note
   loop before touching voice/backend. First ticket: `APP-001`.
3. **Keep it native and minimal.** Prefer Apple APIs, small feature modules, semantic design tokens,
   and zero/few dependencies. Avoid global state, coordinator sprawl, and speculative abstractions.
4. **Never weaken the contracts.** The verbatim-capture contract, the "API key stays server-side" rule,
   and the privacy/logging rules are non-negotiable. If a change would touch them, stop and ask.
5. **Docs and rules travel together.** If you intentionally change a rule or a locked decision, update
   `RULES.md` (and the owning spec) in the same change, and note it in `README.md` §2 if it is a
   locked decision.

## Quick self-check before proposing or writing code

- Does this keep the note more important than the interface?
- Does it violate anything in `RULES.md` §1 (locked constraints), §2 (voice), or §3 (privacy/security)?
- Is a Save button, formatting toolbar, account wall, or emoji-as-interface sneaking in? (Forbidden.)
- Am I about to build something on the do-not-build list (`RULES.md` §7)?
- Is the API key or any note/transcript content about to leave the device or hit a log? (Must not.)

If any answer is uncertain, re-read the spec before acting.
