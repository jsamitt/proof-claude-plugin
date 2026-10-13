---
name: proof-retro
description: "Use periodically — monthly or after a release, not part of every issue, or let the retro routine run it. Owns how the work goes, not what was learned. Looks back over a stretch of work: shipped against planned, where work waited, how estimates held up, which areas keep breaking, how often lessons repeated, whether the goals moved. Posts a retro issue with at most three process changes as tick boxes, and applies the ones ticked"
model: sonnet
---

# Retro

Looks back so the next stretch goes better. `/proof-plan` looks forward; this looks at
what actually happened — and the most useful output is usually a change to how the
harness itself is configured.

```
/proof-retro               # apply what was ticked, then look back since the last retro
/proof-retro 14d           # a specific window
/proof-retro --scheduled   # run by the retro routine — see "Unattended mode"
```

Read `_partials/config.md`, `_partials/voice.md` and `_partials/priority.md` first.

**Nothing changes without a tick.** A retro proposes; it never rewrites the config on its
own judgment. A ticked box is the approval, and even then config changes arrive as a pull
request for the user to merge.

## Where retros live

Each retro is its own issue, titled **Proof retro: {Mon YYYY}** after the month its window
ends in, with the label `proof-retro`. If that title is taken (a second retro in one
month), add ` (2)`. **The retro issue** means the newest open issue whose title starts
`Proof retro:`. There is at most one: posting a new retro closes the one before it.

Retro issues stay on the board. Auto-add puts them there; do not set their stage.

Retros from before this existed are comments headed **Proof retro** on the Proof digest
issue. Read them to find a window; never edit them.

## 0. Apply what was ticked

Before anything else, apply the ticked suggestions in the retro issue. With no retro
issue, or nothing ticked, say so in one line and move on.

1. **Collect.** Every ticked checkbox under *Suggested changes* whose `<!-- proof-retro:… -->`
   marker does not already say `applied` or `acknowledged`.
2. **Re-check before acting.** The config may have changed since the retro. If a change is
   already on the base branch's `.claude/harness.json`, skip it as "already done" and mark
   it so. Never apply twice, and never undo something the user changed by hand.
3. **Apply.**
   - **`config`** — all of them together on **one branch**, `{branch.prefix}retro-{yyyy-mm-dd}`,
     from `branch.base`: one commit per suggestion, changing exactly what its line says,
     then **one pull request** titled *Retro {Mon YYYY}: apply ticked changes*, linking the
     retro issue. If an earlier apply PR from this retro is still open, add the commits to
     its branch instead of opening a second. Never push to the base branch; the user
     merges. Applied means "PR opened", not "in effect" — say so.
   - **`habit`** — nothing to change in the repository. It is acknowledged.
4. **Mark.** Edit the retro issue: append `— applied {date}, #{pr}` or `— acknowledged
   {date}` to each line, and add `applied` or `acknowledged` to its marker. Leave skipped
   lines with a short note saying why.
5. **Report** what was applied, acknowledged and skipped, in a few lines.

An unticked box is not a quiet no; it is simply not a yes yet.

## 1. Set the window

Start from the newest **retro issue, open or closed** — its creation date. With none, use
the newest **Proof retro** comment on the Proof digest issue. With neither, use the last
30 days. A window given as an argument (`14d`) overrides all three. Say which you used.

## 2. Gather

For the window:

- Issues closed, and pull requests merged — with their P-labels and Priority tables
- Each issue's timeline: when it became ready, when work started, when the PR opened,
  when it merged, when it shipped
- Review findings posted on those PRs, by lens and severity
- Learnings posted to issues, and anything promoted to the decisions file
- Commits: which files changed most, and any fix that was itself fixed or reverted
- What `/proof-plan` recommended during the window, if the digest shows it
- Anything still `blocked`, and for how long

Reason from what you gathered. **If something is not recorded, say it is not recorded**
— do not estimate it from general knowledge.

## 3. Look for these six things

**What shipped against what was planned.** Did the work that got done match what was
recommended? Drift is not wrong — plans change — but a pattern of it means the plan is
not being used, or not being trusted.

**Where work waited.** The stage where issues sat longest. For one person the usual
culprit is In Review: work that is built but waiting on a manual check that never
happens. Name the issues.

**Estimates against reality.** Compare each issue's effort rating with how long it
actually took from work starting to PR merged. This is a rough signal — calendar time
includes days you did not work — so look for patterns, not verdicts: *"4 issues rated
Low effort; 3 took over a week."* That is how the ratings get more honest.

**Areas that keep breaking.** Files changed most by fixes, and fixes that needed fixing.
Recurring bugs in the same place are a design problem, and saying so is often the most
valuable line in the retro.

**Repeats.** Count the **🔁 Repeat of** comments posted in the window — learn tags them
the moment they happen, so do not re-derive them. One is noise. Several, or several on
the same entry, mean the record is not being read before work starts in that area. That
is the process problem this section exists to catch: say where it is happening and
propose a fix — for example, adding the area to `review.risk_focus` so the reviewer
checks it every time.

**Goals.** For each goal in `goals`: what moved it in this window, and whether anything
is in progress for it now. A goal nobody worked on for a whole retro window is either
not really a goal, or is stuck — ask which. If `goals` is empty, note once that the
retro would be more useful with them.

## 4. Propose at most three changes

Concrete and small. Usually they are changes to the project's Proof config or habits,
which is how the harness improves itself. For example:

- *"Three fixes this month were in offline sync. Add it to `review.risk_focus` so
  the risk reviewer checks it on every change."*
- *"Work sat in In Review for an average of 5 days waiting on simulator checks. Try
  doing the manual check before the PR, not after."*
- *"Effort ratings ran low on anything touching IAP. Rate IAP work one level higher."*

Not ten, and not vague. *"Communicate better"* is not a change. If nothing needs
changing, say that — a quiet month is a fine result.

Each suggestion is one of two kinds, because a tick does different things to each:

- **`config`** — a change to `.claude/harness.json`. Name the exact key and the exact
  new value in the line, so a tick can be applied without guessing.
- **`habit`** — a change to how the user works. Nothing in the repository changes.

**Lessons are not process changes.** If a finding is really about the product or the
code — *"purchases behave differently in the sandbox than in production"* — it is a
learning, not a retro proposal. List it under *For `/proof-learn`*, without a tick box,
and let the learning rules and their durability gate in `_partials/learnings.md` decide
it. Never write the decisions file from a retro.

**Record health, one line.** Say how many entries the decisions file has and how many
repeats the window saw. If the file is past the recommended size, suggest
`/proof-learn --review` to prune it — do not prune it here.

**Where retro stops and learn starts.** Retro owns *how the work goes*; `/proof-learn`
owns *what the project knows*.

## 5. Post

Open the retro issue, labelled `proof-retro`. If the label does not exist and cannot be
created, post without it and say so. Keep the body readable in two minutes:

```markdown
{_Posted by the retro routine._ — only in unattended mode, and always the first line}

**Window:** {start} to {end}

## What shipped against the plan
## Where work waited
## Estimates against reality
## Areas that keep breaking
## Repeats
## Goals
{each a short paragraph or table; omit nothing — "nothing recorded" is an answer}

## Suggested changes — tick to approve
Ticked changes are applied the next time the retro routine or `/proof-retro` runs.
Config changes arrive as a pull request for you to merge.

- [ ] {the change in plain words} — {why}. Sets `{key}` to `{value}` <!-- proof-retro:{yyyy-mm}:{slug} config -->
- [ ] {the habit in plain words} — {why} <!-- proof-retro:{yyyy-mm}:{slug} habit -->

## For /proof-learn
- {a lesson about the product or code, if any — no tick box}

{record health, one line}
```

Omit *Suggested changes* and *For /proof-learn* when they are empty. The hidden marker on
each tick box is how it is tracked: never omit it, and never change it once posted.

Then **close the previous retro issue**, if one was open: comment *"Superseded by #{new}"*,
listing any suggestions left unticked (they are not carried forward — the new retro
raises them again if they still matter), and close it. Then take it off the board per
`_partials/board.md`, if the board can be reached.

## Unattended mode (`--scheduled`)

Run by the retro routine, in a fresh session, with nobody watching. It applies what was
ticked and posts a retro when one is due — **it never decides anything on the user's
behalf, and never asks.**

1. **Apply what was ticked** — step 0, on every run, even when nothing else happens.
2. **Is a retro due?** Stop here, posting nothing, if the newest retro issue was opened
   less than **28 days** ago, or if no issue was closed and no pull request merged since
   the window would start (step 1). A quiet month is the correct outcome, not a failure.
3. **Run steps 1–5**, with these adjustments:
   - **The board may not be readable.** Work out when issues became ready, started and
     went to review from their label events and pull request dates instead, and say in
     *Where work waited* that the board was not read.
   - **Discussions may not be readable.** Skip them silently.
   - **Nobody can answer a question.** Where a step says to ask (a goal nobody worked
     on), write both possibilities in the retro instead.
4. **End with one line:** what was applied and what was posted — *"Applied 2 ticked
   (PR #41); posted Proof retro: Nov 2026 (#42)."* — or why nothing was posted —
   *"No retro due — the last one is 12 days old. Nothing ticked."*

### Hard limits

In unattended mode, never: edit the decisions file, change anything except
`.claude/harness.json` and that only through a pull request, push to the base branch,
post to or edit the Proof digest issue, start or build any issue, open any issue but the
retro issue, or close any issue but the previous retro issue. If something looks urgent,
**say it in the retro**; do not act on it.

## Hand back

The retro issue's link, what step 0 applied, and the suggestions in one line each.

**Offer the routine** unless the newest retro issue's first line says it was posted by
the routine — that means one already exists:

> Want this to run by itself? A routine checks weekly, posts a retro about once a month,
> and applies what you tick. The nightly digest is not affected.

On a yes, fill in `templates/retro-prompt.md` and walk the user through creating it, per
`/proof-init`'s *Optional: the monthly retro* step. Never create it with a scheduling
tool.
