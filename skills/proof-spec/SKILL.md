---
name: proof-spec
description: Use when turning an idea into something buildable — first checks it against the board for anything it overlaps, supersedes or contradicts and settles each, then explores the problem, proposes approaches, writes acceptance criteria, rates priority, and asks whether it lands as a board-tracked issue or a parked GitHub Discussion; splits oversized work into a parent with sub-issues. Part of every issue
---

# Spec

Turns a thought into something you can build from without asking follow-up questions.
This is the only planning stage — no separate idea tier, no separate technical spec.

The same conversation ends in one of two places, and **the skill always asks which**:
a GitHub **issue** (committed work, goes on the board) or a GitHub **Discussion**
(a worked-out concept, deliberately *not* on the board). There is no mode to remember
and no flag to pass — you are asked at the end, once the draft exists and the choice
is an informed one.

```
/proof-spec "hints should carry over between levels"
/proof-spec 14            # spec an issue that already exists
/proof-spec d/7           # pick up Discussion #7 and finish it
```

Read `_partials/config.md`, `_partials/voice.md`, `_partials/priority.md` and
`_partials/overlap.md` first. Then `project.docs` and any `learnings.file` entries
touching this area — say which past decisions you are applying.

## Checklist

1. Check what already exists — overlaps, supersedes, contradictions — and settle each
2. Ground yourself in the code that this would touch
3. Explore the problem — one question at a time
4. Propose 2–3 approaches with a recommendation
5. Write acceptance criteria
6. Cut the scope
7. Rate priority — propose, then adjust
8. Offer a mockup if it is visual
9. Present the draft, then **ask where it lands** — issue or Discussion
10. Create it and apply what step 1 settled; an issue goes on the board `spec_draft` → `ready`, a Discussion does not
11. Capture the spec learnings
12. Present discovered work

## 1. Check what already exists

Before anything else, run the **full** overlap check in `_partials/overlap.md`: open
issues, open Discussions, recently closed issues and the decisions file, against the idea
as stated. For `/proof-spec <n>`, check the issue against everything except itself.

If nothing overlaps, say so in one line and carry on. If something does, present the
matches and settle each one with the user **now**, in this session — the answer often
changes what the rest of the spec is about. *Spec the existing issue instead* switches
straight to speccing that issue.

Settle, do not apply. Write down what was decided and carry it through the spec; the
changes to other issues happen in step 10, when this one is created.

## 2. Ground first

Read the actual files this would touch before asking anything. Grounded questions
("the tutorial flag is stored per-profile and globally — which should this follow?")
are worth ten generic ones. Bring what you found into the conversation.

## 3. Explore

One question at a time, multiple choice where you can. Cover: what problem this solves,
who hits it and when, and what changes once it exists. Two to four rounds — this is a
spec, not a requirements phase.

Watch for the request that is really three requests. Never write one issue with three
unrelated acceptance criteria — that issue cannot be finished, only abandoned. Say so,
and offer three shapes:

| Shape | When |
|---|---|
| **One issue after all** | It only looked big; the pieces are one coherent change |
| **Separate issues, shared label** | 2–3 pieces that are genuinely independent and can ship in any order |
| **A parent issue with sub-issues** | 3+ pieces serving one goal, where the shared context is worth writing down once |

Recommend one and say why. For the parent shape, the parent holds the goal, the shared
constraints and the running order; each child is independently buildable with its own
acceptance criteria. Use GitHub's native sub-issue relationship, not a checklist of
links in the body — native sub-issues track completion on their own.

The parent goes on the board at `backlog` and **stays there for its lifetime**; children
move through the stages independently. The parent is never worked directly.

**Do not reach for the parent shape by default.** A parent with one or two children is
bureaucracy — it adds a layer that carries no information. If you cannot name shared
context that would otherwise be repeated in each child, use separate issues.

## 4. Propose approaches

Give 2–3 real options — not one plan plus two strawmen. Lead with your recommendation
and the reason. For each: what it costs, what it risks, what it forecloses. Then let
the user choose.

This step is where the harness earns its keep. A solo developer's failure mode is
committing to the first idea; two credible alternatives on the table is the cheapest
correction available.

Present them per `_partials/voice.md`: recommendation first, trade-offs in terms of what
the user experiences and what it costs, technical detail last. If the recommendation
genuinely hinges on something you could find out — a platform limit, a library's actual
behaviour — offer to research it, naming the question and how each answer changes the
call. Otherwise, recommend and move on.

## 5. Acceptance criteria

The contract `/proof-work` builds against and `/proof-review` reviews against. Each one
observable and checkable — a thing you could watch happen, not a quality you could
argue about.

```
- [ ] Using a hint on the last word of a level still leaves the level at minimum 1 star
- [ ] Hint count resets when a level is replayed from the level-select screen
- [ ] Free users see the upgrade prompt on the second hint of a level; Plus users never do
```

Not: "hints work correctly", "good UX", "performance is acceptable".

Also state **out of scope** explicitly. It is the half people skip and the half that
stops the build wandering.

## 6. Cut

Before showing anything, re-read the draft and strip: features nobody asked for, "while
we're in there" additions, configurability with one caller, and anything defending
against a problem the project does not have. Say what you cut — the user may want a
piece of it back, and hidden cuts are how specs lose trust.

## 7. Rate priority

Per `_partials/priority.md`. Propose value, effort and confidence in **one message**, each
with a one-line reason, and the priority they produce. The user confirms or adjusts in
one reply.

Name the goal the work serves, from `goals` — or say plainly that it serves none.
You have just spent the conversation on this problem, so the reasons should be specific
to it — *"parents asked for it in reviews"*, not *"users would find this helpful"*. If a
rating is a guess, say so; that is what the confidence rating is for.

If the table lands on **Reconsider**, say so directly: this may not be worth building.
If confidence is **Low**, recommend a bounded investigation before the work itself.

## 8. Mockup (visual changes only)

Skip silently if there is no visible UI. Otherwise offer one: a single self-contained
HTML file, no network requests, wireframe-level — layout and flow, not polish.

Iterate until the user is happy, then save it next to the issue under
`docs/features/{issue}-{slug}/mockup.html` and attach it to the issue. Do not build a
release-asset upload pipeline for this; a committed file and a link is enough.

## 9. Present, then ask where it lands

Show the full draft. Revise and re-present until it is right. **Create nothing without
an explicit go-ahead.**

Include what step 1 settled and what it will do to other issues ("closes #12 as a
duplicate; updates #19's criteria"), so the go-ahead covers those too. If the scope moved
a long way during the conversation, re-run the overlap check on what is new before
presenting — the idea that was checked may not be the idea being approved.

Then ask — always, every run, even when the answer seems obvious:

> Where should this land?
> **1. Issue** — committed work. Goes on the board at Ready to Dev, buildable now.
> **2. Discussion** — a worked-out concept, parked. Not on the board, nothing owed.

Say which you would pick and why, in one line. The honest default is an **issue** when
the user came in wanting to build the thing, and a **Discussion** when the conversation
kept opening questions rather than closing them, when it depends on something that does
not exist yet, or when the user has said any version of "not yet". A **Reconsider** or a
Low-confidence rating is also a strong signal toward a Discussion.

Asking costs one keystroke. Guessing wrong puts a maybe on the board, and a board full
of maybes is one nobody looks at.

## 10a. Create the issue (if that is the answer)

Title as a capability, not a task ("Hints carry over between levels", not "Add hint
carry-over"). Body:

```markdown
## Problem
{2-3 sentences: what hurts, for whom, when}

## Approach
{the chosen option, and one line on why it beat the alternatives}

## Acceptance criteria
- [ ] ...

## Out of scope
- ...

## Notes
{constraints, affected files, prior decisions being applied}

## Priority: {P1|P2|P3}

| | Rating | Why |
|---|---|---|
| Value | ... | ... |
| Effort | ... | ... |
| Confidence | ... | ... |
```

Then, per `_partials/board.md`: add to the board, set `spec_draft`, and immediately
move to `ready` with the `ready` label — the spec was approved in step 9, so the issue
is ready the moment it exists. Apply the P-label, and `investigate` if confidence is Low. Speccing an existing issue updates it in place.

Then apply what step 1 settled, per `_partials/overlap.md`: comment on and update, close,
or attach as a sub-issue, and record the links in the new issue's Notes. Report each
change with a link.

## 10b. Write the Discussion (if that is the answer)

Create it in the **Ideas** category via `gh api graphql` (there is no `gh discussion`
command). Resolve the repository and category IDs at runtime; never hardcode them.

Same body as the issue, with three changes: the acceptance criteria become a
**Sketch of scope** (unchecked, clearly provisional — they have not been committed to),
add an **Open questions** section holding what the conversation did not settle, and the
Priority section is titled **Provisional priority**. No label — it is not a commitment.

Do **not** add it to the board, do not label it `ready`, and do not open an issue "to
track it". The whole value of this path is that nothing is owed.

Apply what step 1 settled, with one difference: a Discussion never closes or supersedes
an issue. Link the related issues from the Discussion and leave them open.

Report the Discussion URL and say plainly how to pick it up later: `/proof-spec d/<n>`.

### Picking one up later

Given `d/<n>`, read the Discussion as your starting context — the problem, the approach
and the rejected alternatives are already settled, so do not re-litigate them. Still run
step 1: the board has moved on since it was parked, and what it overlaps may have
shipped, changed or been turned down in the meantime. Explore
only the open questions, then continue from step 5 — including a fresh priority rating,
since the provisional one may be stale. When the issue is created, comment
on the Discussion with a link to it so the trail closes.

## 11. Learnings

Per `_partials/learnings.md`, post the **Spec** capture: the decision, why, and which
alternative was rejected. This is the entry you will most want later — it is the only
record of why the other two options lost. If a durable decision came out of it, propose
promotion and wait. If step 1 settled that this spec overrides a recorded decision,
propose superseding it here, per `_partials/learnings.md`.

## 12. Discovered work

Per `_partials/discovered.md`, present anything you found while reading the code.
File only what is approved.

## Hand back

The issue (or Discussion) URL and its stage.

Then **ask what to do next**, per `_partials/chain.md` — never start the next step unasked.
