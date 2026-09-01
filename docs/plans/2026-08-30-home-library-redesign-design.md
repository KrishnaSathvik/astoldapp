# Home library redesign — design

Date: 2026-08-30
Status: approved by the product owner (2026-08-30), implementing.

## What changes

Only the note library **below** Home's header. The header — Profile, Calendar, New Note, Quick
Voice — and `.searchable` keep their positions, their order, and their behavior. No overflow menu,
no bottom toolbar, no moved controls.

The library becomes a compact monochrome grouped list: notes bucketed by relative age, each bucket
drawn as one rounded surface holding several dense rows separated by hairlines.

## Locked rules being amended (and why)

Four constraints in `RULES.md` contradict the new direction. Each is amended deliberately, in the
same change, and noted in `README.md` §2.

| Rule | Was | Becomes |
|---|---|---|
| §1 | "Notes MUST be grouped automatically **by day**" | Grouped by relative period: Today / Previous 7 Days / Previous 30 Days / Older |
| §1, §4.12 | "Home MUST NOT show note creation times on normal rows" | **Unchanged.** Rows carry no time. The spec's `9:41 PM ·` prefix was dropped rather than unlock this. |
| §4 Home | "No card per note by default — prefer `VStack` rhythm over rounded rectangles" | Scoped to "no card per *note*". One rounded surface per *section* is allowed. |
| §4 Home | Row = title + "2–3 line body preview" | Row = title + **one**-line flattened preview, for the density this redesign exists to buy. |
| §4 tokens | Warm `canvas #F8F7F3`, warm dark `textPrimary #F3F2EE` | Neutral palette, app-wide. No brand colour on a content surface. |

The prominent largeTitle `Today` anchor is **removed**: it would be drawn twice once `Today` is also
a section header, and a duplicated heading is a bug VoiceOver reads out loud. Home still leads with
the quiet current date, which is what §4's "subtle current date" asked for.

## Palette

`canvas` stops being the only ground. Two grounds, because a grouped list and a writing page want
different ones:

| Token | Light | Dark | Used by |
|---|---|---|---|
| `canvas` | `#FFFFFF` | `#000000` | Editor, Welcome, Lock, Voice — the writing/content ground |
| `groupedCanvas` (new) | `#F2F2F7` | `#000000` | Home, Calendar, Search — the ground grouped rows sit on |
| `surface` | `#FFFFFF` | `#1C1C1E` | The row/card surface itself |
| `separator` (new) | hairline | hairline | Row dividers, replacing `textTertiary.opacity(0.16)` |

`textPrimary`'s dark value loses its cream cast (`#F3F2EE` → `#FFFFFF`). `accent` and the three
header icon tints are untouched — they are controls, not content.

## Grouping

`timelinePeriod(for:calendar:now:)` buckets a date by whole days between `startOfDay(createdAt)` and
`startOfDay(now)`: `<= 0` Today, `<= 7` Previous 7 Days, `<= 30` Previous 30 Days, else Older.
Calendar arithmetic only — never 24-hour math (RULES.md §5).

`now` is captured **once per render pass** and threaded through, so a pass that straddles midnight
cannot bucket two notes against two different "today"s.

`groupedByDay` and `dayLabel` stay: the calendar's day list still uses them.

## Rendering

A `List` with `.listStyle(.insetGrouped)` and one `Section` per period. Native, so swipe-to-delete,
section semantics, separator insets, and Dynamic Type all keep working — rather than hand-drawing
containers in a `ScrollView` and losing the swipe (RULES.md §4: prefer native controls).

Row: one-line title over a one-line flattened preview, 12pt vertical inset → ~70pt at default type.
An untitled note keeps §4's rule — its first meaningful line is the primary content at body weight,
and the remainder becomes the preview, so every row is the same two-line shape either way.

Previews stay flattened through `StructuredTextExport`: no marker, fence, or pipe reaches a row.
A new `previewLines` returns the already-rendered lines so a checklist collapses to
`☑ Website  ☑ Voice V2  ☐ Screenshots` on one line. `previewText` is unchanged — search depends on it.

## Empty state

Feather mark, `Nothing here yet.`, and the locked tagline as the quiet second line. Not new
encouragement copy, which §4.10 forbids. Creation actions stay in the header and are not duplicated.

## Out of scope

Note schema, ordering, selection, navigation, autosave, Calendar, Search, Quick Voice, New Note,
header icon tints.

---

# Refinement pass — 2026-08-31

Date: 2026-08-31
Status: approved by the product owner (2026-08-31), implemented.

The grouped monochrome direction was right; the hierarchy and the density were not. Seven titleless
voice notes under `Today` all looked equally important, and Home was still the whole archive.

## What changed

| | Was | Becomes |
|---|---|---|
| Scope | All four periods, the entire library | `Today` + `Previous 7 Days`, then **View All Notes** |
| Density | Every note in a period | Capped: 4 today, 5 in the week, `Show all N` expands in place |
| Identity | A profile initial and three glyphs | `As Told` over the library's size |
| Date line | `AUGUST 30, 2026` above `Today` | Removed — it said the same thing twice |
| Untitled rows | Body weight, same as the preview | **Medium** — its own line, not a title it never had |
| Header icons | Terracotta / sage / slate blue | Monochrome; the colorsets are deleted |
| Row height | ~73pt | ~68pt |

## Locked rules amended (again, and deliberately)

Two of these are the load-bearing ones, and both were locked twice — in `RULES.md` §1 and in
`README.md` §2. They are amended in the same change, as the process requires:

- **"Home MUST be the complete chronological notes timeline (no separate 'All Notes' screen)."** The
  parenthetical forbade precisely what now exists. The rule was written when a library was a handful
  of notes.
- **"MUST NOT expose user-facing pagination or a 'Load more' control."** Clarified rather than
  removed: `Show all N` reveals the rest of a period the reader can see the top of, and
  **View All Notes** opens one screen that then loads as it scrolls, invisibly. No page number, no
  batch counter, no button to keep pressing.

Both amendments were **approved by the product owner on 2026-08-31**, with the old parenthetical
("no separate 'All Notes' screen") deleted outright rather than left standing as contradictory
legacy wording.

## The fence

**View All Notes** is the risk this change carries: it is a second browsing surface, which is exactly
what the calendar's fence exists to prevent. It is held to the same fence — period headings and rows,
no search of its own, no sort, no filter, no counts, no second row design — and offered only when
something is genuinely outside what Home draws.

## Not done here

The floating search field is `.searchable`, and its height, material, icon, and placeholder weight
are the system's. Making it 50–52pt would mean replacing it with our own control, which §1 forbids
("Search MUST be available from Home via native pull-down/`.searchable` behavior"). Left native.

## Two details the review settled

- **`Show all 7`, not `Show all 3 more`.** The affordance names the whole period, because that is the
  state of something the reader can see the top of. A remainder count describes a *batch*, and a
  batch is one `Load more` away from being the pagination this product does not have.
- **Expansion lasts the visit.** The expanded set is owned by `HomeView`, not by the list: opening a
  note from an expanded period and coming back must not re-collapse it. It is not persisted across
  launches — it is a way of looking, not a setting.

---

# Second refinement pass — 2026-08-31

Date: 2026-08-31
Status: approved by the product owner (2026-08-31), implemented.

The first refinement fixed the scope and the density. It also introduced three things that read as a
half-finished hybrid, and each is reverted or narrowed here. Nothing about the grouped list, the
periods, the caps, or the row shape changes.

## What changed

| | Was (first refinement) | Becomes |
|---|---|---|
| Home's lead | `As Told` largeTitle over `14 notes` | The subtle current date over the first period heading — the pre-redesign lead, restored |
| Header glyphs | Monochrome `textPrimary` | Four distinct muted tints; Quick Voice gets its own |
| `Show all N` | One-way | Reversible — `Show less` in the same place |
| Archive | Unconditional `View All Notes` | `Browse older notes ›`, drawn **only** when notes sit outside Home's periods |

## Why each

**The title block.** It cost a largeTitle and a subtitle above the first note and answered no question
anyone arrives with. The app's name is on the icon just tapped; the count is a statistic, which §4
already forbids Home from showing — the rule was read as being about *streaks and stats*, but a note
count is exactly the same kind of thing. Removing it also removed the reason the date line was cut:
the date is small, tertiary and all-caps, and does not compete with the `Today` under it the way a
largeTitle did.

**The header colour.** "Home goes monochrome" was applied one step too literally. What the neutral
palette protects is the *content surface* — no brand tint behind the writing, competing with the
feather mark. Four navigation glyphs in one corner are not a content surface, and identically inked
they have to be read before they can be told apart. Quick Voice gets `iconVoice` rather than sharing
New Note's slate blue: writing and speaking are peers (`docs/10-voice-v2.md` §1), and drawing one as
the other's second button said otherwise.

**`Show less`.** A one-way expander turns a fourteen-row group into a wall with no way back short of
leaving Home, which makes a glance feel like a commitment. Same control, same place, so the way back
is never somewhere to look for. It is not pagination running backwards — it reveals nothing and
restores a presentation rule.

**The conditional archive.** This was the real duplication. With a library that fits inside Home's
periods, `Show all 14` and `View All Notes` led to the same fourteen notes; the second one had
nothing to do. The affordance now appears only when `HomeLibrary.hasOlderNotes` is true — deliberately
*not* when some period is merely capped, which is the distinction the whole fix rests on. It is also
renamed to say why you would tap it. The screen keeps the title `All Notes`, which names where you
have arrived rather than a destination you have not chosen.

## Not done here

Both of these were asked for and both were **measured off a full-size screenshot** rather than
estimated, because a number read off the tokens is not a number anyone can see:

- **The grouped surface's corner radius stays the platform's.** The refinement asked for 18–20 pt;
  `.listStyle(.insetGrouped)` on iOS 26 measures **~20 pt** with a **16 pt** side inset, so it is
  already there. SwiftUI exposes no API to set a section's radius — reaching an exact number would
  mean hand-drawing rectangles in a `ScrollView` and losing swipe-to-delete, which `RULES.md` §4
  forbids trading away. Same reasoning as `.searchable` in the pass above.
- **Row height stays as it is.** The refinement asked for 64–68 pt; the rows measure **65–66 pt**,
  already tightened from ~73 in the first pass. Cutting further would need a non-token inset.
- Voice, transcription, and the editor are untouched.

## Testable boundaries added

`HomeLibrarySection` gained `isExpanded` and `isCollapsible`, so "a period that never reached its cap
offers neither label" is a unit test rather than a screenshot. `NoteRowContent` was lifted out of
`NoteRow`, so "a chosen title outranks a first line" is checked by comparing two `Font`s rather than
by looking at a row.


---

# Third refinement pass — 2026-08-31 (row hierarchy only)

Date: 2026-08-31
Status: approved by the product owner (2026-08-31), implemented.

The Home architecture is approved and untouched here: periods, caps, the reversible `Show all N`,
the conditional archive, the header, Calendar, Search, colors, navigation and Voice all stay exactly
as they are. **One thing changes: the note row.**

## The defect

A titleless note was still being drawn with a title. Both earlier attempts promoted its first body
line into the primary slot and only argued about the weight — semibold, then medium. Both were the
same mistake in different amounts, and the screenshots showed it: a transcript opening
`Okay, let's talk about that right now…` sat in the list looking exactly like the chosen title
`3 Realistic Paths` two rows below it.

The rule that fixes it is simpler than either attempt, not more subtle:

> The primary/semibold treatment means **the writer named this note**, and nothing else earns it.

So a titleless note gets **no title line at all**. Not a quieter one.

| | Title line | Excerpt |
|---|---|---|
| Titled | `body` semibold, `textPrimary`, 1 line | `subheadline` regular, `textSecondary`, 2 lines |
| Titleless | *none* | `body` regular, `textSecondary`, 2 lines |

The titleless excerpt carries its emphasis in **size** rather than weight — body rather than
`subheadline`, because with nothing above it the excerpt *is* the row. Weight is now reserved
entirely for titles, which is what makes the list scannable: black semibold text means a human named
this.

## Two lines, and the height that follows

The excerpt went from one line to two, with the same limit for every row so truncation is
deterministic. It also now carries the **whole** body in both cases — a titleless note no longer
spends its first line paying for a title it never had.

**Rows stop being a uniform height, deliberately.** That uniformity was the argument for the one-line
preview in the first pass, and it is what cost the excerpt its second line. A titled note has three
lines of content and a titleless one has two; forcing them to match can only be done by starving one.

Measured with the inset unchanged at 12 pt: a titled row with a two-line excerpt is **85–87 pt**, a
titleless one **67 pt**. The pass asked for 76–84, so the titled row is 1–3 pt over. Left there on
purpose: the line heights are Dynamic Type's, the inset is the only lever, and the next step down the
4-pt scale (12 → 8) leaves 8 pt between a divider and the text — tighter than the row was *before*
this pass, which is the opposite of what it was for. Reported rather than quietly hit by cramping the
thing the change exists to loosen.

## Colour

Semantic tokens only, unchanged in value: `textPrimary` for a title, `textSecondary` for an excerpt.
`textSecondary` is `#5B5B61` / `#ADADB4` — plainly subordinate to a title and plainly not disabled,
which was the explicit caution. Nothing drops to `textTertiary`, which is where "disabled" starts.

## Not done here

- **No new UI tests, and none run for this pass** — asked for explicitly. The row-content and style
  decisions are pure and covered by unit tests; the existing UI suite is unchanged and its last full
  run (101 green) still stands for everything this pass did not touch.
- Search's own result row is a different surface and was left alone.


---

# Calendar pass — 2026-08-31

Date: 2026-08-31
Status: approved by the product owner (2026-08-31), implemented. **Home is frozen** as of this pass;
only the calendar changed.

## The structural bug, found in code rather than in a screenshot

The page was a `VStack` holding the grid above a `List`. The `List` scrolled **inside** the page, so a
day with eleven notes gave the reader two stacked scrolling surfaces with no way to tell which one a
drag would move — and no way to scroll the grid back into view from inside the notes.

It is now one `ScrollView` containing the header, the grid, the heading, the notes, and the toggle.
The notes are a plain `VStack`; nothing here needed `List`, because the calendar's rows deliberately
carry no swipe-to-delete (the note's own overflow covers it).

## The rest

| | Was | Becomes |
|---|---|---|
| Scrolling | grid + nested scrolling `List` | one `ScrollView` |
| Selected day | every note, however many | 4, then `Show all N` ⇄ `Show less` |
| Heading | `Today` / `Yesterday` / `August 15` | `Today`, else `Saturday, August 29` |
| Day indicator | one dot, note or no note | 1–3 sage dots by density |
| Accent | app navy (`accent`) | the calendar's own sage (`calendarAccent`) |
| Today, unselected | navy **number** | thin sage **ring** |
| Selected | navy filled circle | sage filled circle |

**Four, not five.** Home's `Today` is capped at four and its week at five; the calendar takes four
because the grid above it is tall, and eleven notes under it pushed the calendar itself several
screens up.

**Three dots, never more.** A count is a badge and seven dots is a bar chart; both make a calendar a
dashboard. The dots carry no category and never will — `Note` owns no type, tag, or colour for
anything to render, and a voice-created note is an ordinary note. The accessibility value speaks the
**exact** count, because state is never carried by colour alone.

**Today's ring vs. the selected fill** are different shapes rather than different colours, since both
are true on the day the screen opens.

## The measurement that changed a decision

The obvious implementation was to fill the selected day with `iconCalendar`, the sage the header glyph
already wears. Measured, that is **4.02:1** against white — fine for a symbol, and below the 4.5:1
floor this codebase holds every glyph to the moment a day *number* is drawn on top of it.

So `calendarAccent` is the same hue 12 % darker in Light (`#457968`) and the glyph's own light sage in
Dark. Verified from rendered pixels, not from the token: **5.01:1** Light, **8.80:1** Dark. One new
colorset, chosen by measurement rather than taste — it is the sage, corrected to the floor.

## Persistence

`noteDays(in:) -> Set<Date>` became `noteDayCounts(in:) -> [Date: Int]`. The fetch, the predicate and
the `userVisibleNotes` filtering are unchanged to the character; only the projection is richer, and
`Set(result.keys)` is still exactly the old answer — which is now a test.

## Not done here

No UI tests were added or run, as agreed. The density banding, the day cap, the heading, and the
spoken cell value are all pure and unit-tested; the calendar's existing UI tests were left untouched.
