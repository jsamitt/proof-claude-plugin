---
name: proof-work
description: Use when building a specced GitHub issue end to end — plans, pauses once for approval, then implements, verifies, records learnings, opens a PR and updates the board without further interruption. Part of every issue
---

# Work

Takes a ready issue to an open PR. **One pause: the plan.** After you approve it, this
runs to a PR without stopping to ask — that is the deal, and it is what makes the
harness usable rather than a checklist you abandon.

```
/proof-work 14
/proof-work 14 --guided     # pause at each acceptance criterion instead
```

Read `_partials/config.md`, `_partials/voice.md` and `_partials/changelog.md` first.

## Checklist

1. Fetch the issue and check it is ready
2. Claim it; board → `in_dev`
3. Branch
4. Plan — **pause for approval**
5. Build
6. Verify
7. Keep the docs true; add the changelog line
8. Learnings
9. PR; board → `in_review`
10. Discovered work

## 1. Fetch and check

Read the issue: its user stories, acceptance criteria and out-of-scope list, plus `project.docs` and
any `learnings.file` entries touching this area.

**If the issue has the `needs_design` label**, stop: it is waiting for a design. Say so,
and point to `/proof-handoff {n} <link>`.

**If the issue has a `## Design` section**, read `_partials/design-record.md` and the
frozen copy it points to. The design is part of the contract: each state's criteria are
acceptance criteria like any other. If the frozen copy is missing, or a state in the
criteria has no design, stop and say so — building from memory of a design is how it
drifts.

Stop and say so if there are no acceptance criteria (run `/proof-spec {n}` first), or
the criteria are too vague to build against. Starting anyway and improvising the spec is
the single most expensive failure mode here.

**Already `in_progress`?** Look for a **Checkpoint** comment on the issue (see *Keep a
checkpoint* below). If there is one, this is a **resume**: check out its branch, read what
is done and what is next, confirm in one line that the approved plan still stands, and
carry on from *Next* — skipping the claim and plan steps. If there is no checkpoint, the
issue was claimed some other way: stop and ask rather than guessing.

## 2. Claim

Add the `in_progress` label, remove `ready`, set the board to `in_dev`, and comment on
the issue that work has started. Per `_partials/board.md`.

## 3. Branch

`{branch.prefix}{issue-number}-{short-slug}` from `branch.base`. Never work on the base
branch. No worktrees — a branch is enough for one person working on one thing.

## 4. Plan — the one pause

Present, briefly:

- **What changes** — the files, and what happens to each
- **In what order** — and where it could be verified partway
- **What it touches that the issue did not mention** — shared state, migrations,
  anything with blast radius beyond the diff
- **What you are unsure about** — the honest list, not a confidence performance
- **With a design:** the components to reuse, change and create, as the record lists
  them, and anything on the canvas you cannot build as drawn, with what you would do
  instead. Raise it here, not mid-build

Write it per `_partials/voice.md`: what the user will notice first, then the mechanics.

Then stop and wait. Under `--guided`, also pause after each acceptance criterion.

Keep it to what a person can read in a minute. A plan long enough to skim past is a
plan that got approved without being read.

## 5. Build

Work criterion by criterion, in the plan's order. Commit at each meaningful step with
`(refs #{n})` in the message.

**With a design:** commit its frozen copy first, so the target goes in with the change.
Build to it — the copy word for word, the colours and spacing through the project's
tokens rather than the canvas's raw values, and every state in the record. Where you
must depart from it, that is a decision the plan did not anticipate (below), not a
detail to absorb quietly.

**On tests:** write them where they carry weight — logic with real branching, anything
with money, auth, or data loss attached, anything a past learning says broke before.
Do not write a ceremonial test per criterion to look thorough, and do not skip tests on
a payment path because the criterion did not mention them. If `commands.test` is null
there is no suite to add to; note that as discovered work rather than inventing one
mid-run.

**Stay inside the lines.** Anything outside the acceptance criteria goes on the
discovered-work list. That includes bugs you spot and could fix in two minutes — collect
them. The exception is a bug that makes the current work untestable: fix it, and say
clearly in the PR that you did and why.

Never touch `protected_paths`.

**Keep a checkpoint.** Work gets interrupted, and the next session may be on a different
machine or in the cloud. Keep **one** comment on the issue, edited in place — never a new
comment each time — so anyone can pick up exactly where this left off:

```markdown
### ⏸ Checkpoint — {date}

**Branch:** `{branch}`
**Done:** {criteria finished, one line each}
**Next:** {the very next step, concrete enough to start on cold}
**Open questions:** {anything waiting on the user, or "none"}
```

Update it after each acceptance criterion, and whenever work stops for any reason. It
lives on GitHub rather than on one machine, so it follows the work wherever it resumes.
When the PR opens, mark it **Complete**.

**Decisions the plan did not anticipate.** You will hit some. The approved plan was
consent for the plan — not for decisions nobody has seen yet. So:

- **Easy to undo, and fits the plan's intent** → make the call, and list it in the PR's
  Notes so it gets reviewed rather than slipping through.
- **Hard to undo, changes what users see or experience, or touches a risk area** → stop
  and ask, framed per `_partials/voice.md`: what changes for the user, what each option
  costs, your recommendation. This is the one pause worth taking after the plan is
  approved.

## 6. Verify

Run every command in `verify.steps`. Report real output. Fix what fails and re-run.

**With a design**, check each state in the record against what you built, and say how:
if this session can run the UI (a dev server, a simulator tool), put each built state
beside its artboard and report what differs; if it cannot, add every state to the manual
list below. A state you did not look at is not matched.

Then surface `verify.manual` as an explicit list for the user — the checks only they can
do. **Never describe a manual check as passed.** "Tested in the simulator" is a claim
only a human can make, and a harness that fabricates it is worse than one with no
verification at all.

## 7. Keep the docs true; add the changelog line

**Docs.** Before the PR, check whether this change made anything in the project's docs
wrong — `project.docs`, the README, and any doc they point to. Look for exactly the
things a change makes stale: tables of screens or routes, database tables and columns,
API endpoints, environment variables, commands, conventions, file paths.

- **Factual updates** that follow directly from the diff — a new route in the routes
  table, a renamed column — make them in this PR, without asking.
- **Judgment calls** — rewriting how something is explained, removing a section, a
  convention that may have changed — ask first.
- Never pad docs. If nothing is stale, say "docs checked, nothing stale" in the PR.

A stale project doc is worse than a missing one: every future session reads it and
believes it.

**Changelog.** Per `_partials/changelog.md`, add this change's line to `[Unreleased]` —
if it earns one. Say in the PR which it was.

## 8. Learnings

Per `_partials/learnings.md`, post the **Build** capture — the gotchas and corrections,
the things that cost time. If nothing met the bar, say so and post nothing.

## 9. PR

Open it against `branch.base`:

```markdown
## What
{one paragraph}

## Closes
Closes #{n}

## Acceptance criteria
- [x] ... {how each was satisfied}

## Verification
{commands run, real results}

**Needs manual check:** {verify.manual items, unticked}

## Design match
{only with a design: each state — matched, differs (how, and why), or not checked}

## Docs and changelog
{docs updated, or "docs checked, nothing stale"} · {changelog line added, or "no user-facing change"}

## Notes
{deviations from the plan, and why}
```

Board → `in_review`, remove `in_progress`, comment the PR link on the issue.

## 10. Discovered work

Per `_partials/discovered.md`. File only what is approved.

## Hand back

PR URL, verification results, and what still needs a human check.

Then **ask what to do next**, per `_partials/chain.md` — never start the next step unasked. If the user pauses here, the chain
offers a learnings sweep first: this session is the only place the build conversation
exists, and it is usually where the lessons are.

## If it goes wrong

Stop and report — do not thrash. Update the **checkpoint** with where you got to and
exactly what blocked you, add the `blocked` label, and leave the branch and commits in
place. Keep `in_progress` on, so the next `/proof-work {n}` resumes from the checkpoint
instead of starting over. A clear stop is recoverable; a half-finished run that
reported success is not.
