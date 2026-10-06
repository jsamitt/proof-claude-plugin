---
name: proof-retro
description: "Use periodically — monthly or after a release, not part of every issue. Owns how the work goes, not what was learned. Looks back over a stretch of work: shipped against planned, where work waited, how estimates held up, which areas keep breaking, how often lessons repeated, whether the goals moved. Ends with at most three process changes, proposed not applied"
---

# Retro

Looks back so the next stretch goes better. `/proof-plan` looks forward; this looks at
what actually happened — and the most useful output is usually a change to how the
harness itself is configured.

```
/proof-retro             # since the last retro, or the last 30 days
/proof-retro 14d         # a specific window
```

Read `_partials/config.md`, `_partials/voice.md` and `_partials/priority.md` first.

**Nothing changes without a yes.** A retro proposes; it does not rewrite the config.

## 1. Set the window

Find the last retro — a comment headed **Proof retro** on the project's Proof digest
issue — and start from its date. With none, use the last 30 days. Say which window you
used.

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

**Lessons are not process changes.** If a finding is really about the product or the
code — *"purchases behave differently in the sandbox than in production"* — it is a
learning, not a retro proposal. Hand it to the learning rules: propose it through the
durability gate in `_partials/learnings.md`. Never write the decisions file directly
from a retro.

**Record health, one line.** Say how many entries the decisions file has and how many
repeats the window saw. If the file is past the recommended size, suggest
`/proof-learn --review` to prune it — do not prune it here.

**Where retro stops and learn starts.** Retro owns *how the work goes*; `/proof-learn`
owns *what the project knows*.

## 5. Post and apply

Post the retro as a comment on the Proof digest issue, headed
**## Proof retro — {start} to {end}**, so it is found next time. Keep it readable in two
minutes: the six sections as short paragraphs or tables, then the proposals as
checkboxes.

Apply only the proposals the user approves. Config changes go through a branch and a
pull request like any other change to the repository.
