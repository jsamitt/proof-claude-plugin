# The digest

A short daily note posted as a comment on the project's **Proof digest** issue. It is
written by the nightly run, and it is where the user makes calls from their phone:
each proposal is a checkbox, and ticking it is the approval.

Both the nightly run and `/proof-plan` apply ticked items using the rules below, so
"apply tonight" and "apply now" do exactly the same thing.

## Finding the digest issue

An open issue titled **Proof digest** in the project repository. If none exists, create
it with a body explaining how it works (see the end of this file), and ask the user to
pin it — pinning keeps it one tap away and cannot be done from here.

## Format

```markdown
## Proof digest — {weekday} {day} {month}

**Yesterday:** {two or three sentences: what moved, what shipped, what got stuck}

**Suggested next**
1. #{n} {title} — {one-line reason}
2. …
3. …

**Needs your call** — tick to approve; applied tonight, or now with `/proof-plan`
- [ ] {proposal in plain words} — {why} <!-- proof:{id} -->

**Still open from {day}**
- [ ] {carried proposal} <!-- proof:{id} carried -->

{one line of anything else worth knowing, if any}
```

Rules:

- Write per `_partials/voice.md` — this is read on a phone, first thing, by someone
  deciding in seconds. Plain words; no jargon; issue numbers always with a title.
- **At most five items under "Needs your call"**, highest value first. If there are
  more, say how many and point to `/proof-plan`. A list too long to answer does not get
  answered.
- Omit any section with nothing in it. Never post "No items" filler.
- The hidden `<!-- proof:… -->` marker on each checkbox line is how items are tracked.
  It is invisible on GitHub. Never omit it and never change it once posted.

## Item IDs

| Proposal | ID |
|---|---|
| First rating for an unrated issue | `rate:{issue}:{P1\|P2\|P3}` |
| Change a rating | `rerate:{issue}:{from}:{to}` |
| Close as a duplicate | `close:{issue}:dup:{kept}` |
| Close as superseded | `close:{issue}:superseded:{by}` |
| Close as abandoned | `close:{issue}:stale` |
| Add a learning to the decisions file | `decision:{issue}:{short-slug}` |

## Applying ticked items

1. **Collect.** Read digest comments from the last seven days. Take every checkbox that
   is ticked and whose marker does not say `applied`. If the same ID appears more than
   once (a carried item), treat it as one.
2. **Re-check before acting.** Things change between the digest and the tick. If an
   issue is already closed, a label already set, or a decision already recorded, skip it
   and report "already done" — never apply twice, never undo a change the user made by
   hand since.
3. **Apply.**
   - `rate` / `rerate` — set the new P-label, remove any other P-label, update the
     Priority table in the issue body, and add a dated line saying what changed and why.
   - `close:*` — comment first with the reason and a link to what replaced it, then
     close. A closed issue with no explanation is a dead end for anyone who finds it later.
     Then take it off the board per `_partials/board.md`, if the board can be reached.
   - `decision:*` — gather **all** ticked decisions into **one** branch and **one** pull
     request adding them to `learnings.file`. Never push to the base branch; the user
     merges the PR. Applied means "PR opened", not "recorded" — say so.
4. **Mark.** Edit the digest comment: append `— applied {date}` to each applied line (with
   the PR link for decisions), and add `applied` to its marker. Leave skipped items
   with a short note saying why.
5. **Report** what was applied, what was skipped and why, in a few lines.

**Only ticked items are applied.** An unticked box is not a quiet no; it is simply not a
yes yet.

## Carrying forward

An unticked item from the previous digest that is **still valid** appears once more
under "Still open from {day}", with `carried` added to its marker. An item already
carried once is not carried again — if it did not earn a tick in two days, it drops off.
`/proof-plan` will raise it again if it still matters.

## The digest issue's body

```markdown
Proof posts a short note here after days you worked on the project.

- **Suggested next** — what to pick up, in order, and why
- **Needs your call** — tick a box to approve it. Ticked items are applied that night,
  or straight away if you run `/proof-plan`
- Anything you leave unticked is carried forward once, then dropped

Nothing here changes anything until you tick it.
```
