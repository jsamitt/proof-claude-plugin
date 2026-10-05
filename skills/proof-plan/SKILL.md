---
name: proof-plan
description: Use periodically — not part of every issue — to decide what to work on next and in what order, re-check priorities that have gone stale, and optionally clean up duplicate, superseded or abandoned issues. Proposes; changes nothing without approval
---

# Plan

Looks across the whole board and answers one question: **what should I work on next, and
in what order?** Optionally, it also tidies up — the backlog that nobody prunes is the
backlog nobody reads.

```
/proof-plan              # apply anything you ticked in the digest, then: what's next
/proof-plan --cleanup    # also look for duplicates, superseded and stale issues
```

The nightly schedule runs `/proof-plan --nightly` — see the end of this file. You never
need to type that yourself.

Read `_partials/config.md`, `_partials/voice.md`, `_partials/priority.md` and
`_partials/digest.md` first.

**Nothing changes without a yes.** This skill proposes. Labels, ratings, closures and
promotions all wait for approval, exactly like discovered work.

## 0. Apply what you already approved

Before anything else, check the **Proof digest** issue for ticked items not yet applied,
and apply them per `_partials/digest.md`. Ticking was the approval — do not ask again.
Report what was applied in a few lines, then carry on.

This is what makes "apply now" work: tick boxes on your phone, open a session, run
`/proof-plan`, and they are done before anything else happens.

## 1. Gather

- Every open issue: title, labels, stage on the board, last activity, and its Priority
  section if it has one
- What is in flight: anything In Dev or In Review, and any open PRs
- What shipped recently, and what learnings were recorded since the last plan — both are
  the usual reasons a rating has gone stale
- Parked Discussions in the Ideas category
- Parent issues and their children, so sequencing respects the grouping

## 2. Rate anything unrated

Issues filed as discovered work, or created outside `/proof-spec`, arrive with no rating.
Propose ratings for them per `_partials/priority.md` — all of them in one table, one
reply to confirm.

## 3. Re-check ratings that may have gone stale

Do not re-rate everything; that is noise. Re-check an issue only when something happened
that could change its rating:

- A related issue **shipped** — this one may now be easier, redundant, or more valuable
- A **learning** changed an assumption the rating rested on
- An **investigation finished** — the Low confidence it was waiting on is now resolved
- It has **sat untouched for about three months** — it was either more important than it
  looked (it keeps being worked around) or less (nobody missed it)

For each, propose the change and say what triggered it. On approval, update the label and
the Priority table together, with a dated line explaining the change.

## 4. Recommend what's next, in order

Priority is where sequencing starts, not where it ends. Work through these in order:

1. **Finish before starting.** Anything In Review or In Dev comes first. A half-finished
   issue costs more every day it sits, and starting something new is how work piles up
   unfinished.
2. **Check what's in flight.** For one person, one or two things at once is plenty. If
   more are open, say so and recommend which to finish or shelve — before recommending
   anything new.
3. **Unblock first.** If A has to happen before B can, A goes first even at a lower
   priority. Say what it unblocks.
4. **Investigate early.** Items marked `investigate` go near the front. They are usually
   small, and what they reveal can reshuffle everything below them.
5. **Batch neighbours.** Issues touching the same screen or area are cheaper done
   together. Point out the pairing.
6. **Then by priority.** Within what is left, P1 before P2 before P3.

**Check against the goals.** If `goals` is set, say which goal each recommendation serves.
Flag two things plainly: a *Next up* list where nothing serves any current goal, and a
goal with nothing ready or in progress. Either one means the backlog and the goals have
drifted apart — the question is which one to change.

Recommend **three**, in order, each with a one-line reason. Not ten. A long list is a
backlog, not a recommendation.

## 5. Clean up (with `--cleanup`, or offered when obvious)

Look for:

- **Duplicates** — two issues describing the same thing. Propose which one survives and
  what to carry over from the other.
- **Superseded** — issues made unnecessary by work that shipped.
- **Abandoned** — untouched for months and no longer rated above P3. Propose closing with
  a note, or parking as a Discussion if the idea is still worth keeping.
- **Discussions ready to promote** — parked concepts whose blocker is gone. *"This was
  waiting on #12, which shipped."* Propose running `/proof-spec d/<n>`.
- **Discussions ready to let go** — parked for a long time with nothing pointing at them.

Closing is cheap to undo but easy to regret. When closing, always leave a comment saying
why and linking what replaced it, so a future search lands on an explanation rather than
a dead end. Then take it off the board, per `_partials/board.md` — otherwise it shows as
shipped.

`/proof-spec` checks each new idea against the board on the way in (`_partials/overlap.md`).
This sweep catches the rest: issues that arrived another way, and pairs that did not
overlap when they were written but have drifted together since.

## 6. Present

One view, in this order, per `_partials/voice.md`:

```
In flight — finish these first
  #14  Freeze carry-over — In Review; needs your simulator check

Next up
  1. #22  Crash on a habit with no entries — P1, and it blocks #23
  2. #19  Can reminders fire offline? — needs investigation; the answer reshapes #20 and #21
  3. #23  Weekly summary email — P1, once #22 is done

Needs your call
  a. #17  P2 → P3 — #12 shipped and covers most of it
  b. #15  Duplicate of #9 — close #15, carry its screenshot across?
  c. #31  Unrated — proposed P2 (Medium value, Low effort, High confidence)

Reply with the letters to approve, "all", or "none".
```

Keep "Needs your call" to about five items, highest value first. If there are more, say
how many, and offer to go through the rest. A list too long to answer does not get
answered.

## 7. Apply what was approved

Apply only the approved items. Report what changed, with links. Leave everything else
exactly as it was — unapproved proposals are not re-raised next time unless something
new has happened to them.

## Nightly mode (`--nightly`)

Run by the schedule, in a fresh session, with nobody watching. It posts a digest and
applies what was ticked — **it never decides anything on the user's behalf.**

### 1. Only on days with activity

First, check the project repository for activity by its owner in the last 24 hours:
commits pushed to any branch, pull requests or issues opened, updated, commented on or
relabelled, **or** ticked-but-unapplied items in the digest (ticking counts as working).

If there is none, **stop immediately.** Post nothing and end with one line: "No activity
— nothing posted." A quiet night is the correct outcome, not a failure.

### 2. Apply ticked items

Per `_partials/digest.md`.

### 3. Build the digest

Run steps 1–5 above, with these adjustments:

- **Board stages may not be readable** from a scheduled session. If the board cannot be
  reached, infer stages from labels (`in_progress`, `ready`) and open pull requests,
  and say nothing about it in the digest — this is expected.
- **Discussions may not be readable** either. If not, skip them silently; the next
  interactive `/proof-plan` covers them.
- **Cleanup is light**: include only duplicates and superseded issues you are confident
  about. Leave abandoned-issue sweeps to an interactive run.

### 4. Curate learnings

The nightly run **cannot see the day's conversations** — only what reached GitHub. So
its job with learnings is curating, not collecting:

- Read learnings posted to issues in the last 24 hours. Apply the durability gate in
  `_partials/learnings.md`; propose the ones that pass as `decision:` items.
- Look for lessons the trail shows but nobody wrote down: a fix that was reverted and
  redone differently, a review finding that sent work back, a PR that changed direction.
  Propose these only when the trail makes the lesson clear — never guess at what
  happened in a conversation you did not see.
- If a new learning repeats something already in the decisions file, tag it per
  `_partials/learnings.md` (a **🔁 Repeat of** comment on the issue) and mention it in the
  digest's last line. Leave any pattern across repeats to `/proof-retro`.

### 5. Post

Compose the digest per `_partials/digest.md` and post it as a new comment on the digest
issue, creating the issue if it does not exist. Carry forward per the digest rules.

### Hard limits

In nightly mode, never: start or build any issue, change application code, close or
relabel anything that was not ticked, create issues, push to the base branch, or touch
anything outside the project repository and its digest. If something looks urgent — a
failing build on the base branch, a PR stuck for a week — **say it in the digest**; do
not act on it.

