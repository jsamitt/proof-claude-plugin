---
name: proof-fix
description: Use when something is broken — finds the root cause before changing anything, confirms it, fixes it with a test that proves it, and opens a PR. The path every bug takes, instead of spec and work. Part of every bug
---

# Fix

For bugs. A feature starts from what should exist; a bug starts from something that
does not work, and the expensive mistake is fixing the symptom. So this skill has one
rule above all others:

> **No fix without the root cause.** A fix that does not address the cause moves the bug
> somewhere harder to find.

```
/proof-fix "the paywall stays open after subscribing"
/proof-fix 31            # a bug that already has an issue
```

Read `_partials/config.md`, `_partials/voice.md` and `_partials/priority.md` first.
Then `project.docs`, and any `learnings.file` entries touching the area — say which you
are applying.

## Checklist

1. Pin down the symptom; file or claim the issue
2. Reproduce it
3. Find the root cause — and prove it
4. Propose the fix — **pause for approval**
5. Fix it, with a test that fails before and passes after
6. Verify, keep the docs true, add the changelog line
7. Learnings, PR, discovered work

## 1. Pin down the symptom

Get it concrete before touching anything: what happens, what should happen, where, for
whom, how often, and since when. One question at a time. *"The paywall is broken"* is
not a symptom; *"after a successful purchase on iPhone the paywall stays open with the
Subscribe button still showing"* is.

Also establish **severity**, because it changes what comes first:

- Does it lose or corrupt data, take money wrongly, expose something private, or break
  for every user? That is urgent — see *When it is on fire* below.
- Otherwise it is ordinary: rate it per `_partials/priority.md`. For a bug, value is the
  cost of leaving it broken — who hits it and how badly.

**If there is no issue**, first check whether it is already reported — the light overlap
check in `_partials/overlap.md`. A match means working that issue instead, with the new
details added as a comment; a match that was closed as fixed may mean the bug came back,
which is worth saying before you look for the cause. Only then create one: the symptom
as the title, the details in the body, the `bug` label, and the P-label from the rating.
**If there is one**, read it. Either way,
claim it: `in_progress` on, board to `in_dev`, per `_partials/board.md`.

## 2. Reproduce it

Make it happen, on purpose, before changing any code. A bug you cannot reproduce is a
bug you cannot confirm you fixed.

- Best: a failing automated test that shows the bug. It becomes the regression test.
- Next: exact steps that trigger it every time.
- If only the user can trigger it — on a device, with their account, in production —
  write the exact steps and **ask them to confirm**, rather than guessing.
- If it will not reproduce: say so, gather more evidence (logs, the exact inputs), or add
  logging so it can be caught next time. Do not fix what you cannot see.

## 3. Find the root cause — and prove it

Trace from the symptom back to the cause:

- Read the code on the path. Follow the data, not the function names.
- **Check what changed recently** in the files involved. Was this working before? A
  regression means the cause is probably in that change.
- **Check the history of the area.** If this is the third bug in the same files, that is
  worth saying out loud: it is a design problem, not bad luck.
- Common shapes worth checking against: a missing guard on an empty or null value; state
  updated in one place and read stale in another; timing between two things that assume
  an order; behaviour that differs between the test environment and the real one; a
  cached value that outlives what it describes.

Then state it as one testable sentence: **"Root cause: …"** — and **prove it** before
fixing it. A log line, an assertion, or the failing test showing exactly what you
predicted. A hypothesis you have not checked is a guess.

**Three strikes.** If three hypotheses turn out wrong, stop and ask, with options:
keep going with a named new hypothesis, add logging and wait for it to happen again, or
treat it as a design problem that needs a spec. Do not try a fourth guess silently.

**Stay in the area.** Once the cause is found, edit only what the fix needs. Anything
else you notice goes on the discovered-work list.

## 4. Propose the fix — the one pause

Present, per `_partials/voice.md`:

- **What was wrong** — for the user, then the cause in a sentence
- **The fix** — the smallest change that removes the cause
- **Blast radius** — which files, and what else could be affected. If it touches **more
  than five files**, say so plainly and offer to split it or look for a narrower fix: a
  bug fix that sprawls is usually treating several things at once
- **How it will be proven** — the test, or the exact repro steps

Then wait for approval. After that, run to a PR without stopping, as `/proof-work` does.

## 5. Fix it

The smallest change that removes the cause. **Not** the symptom: no special-casing the
one input that failed, no retry around something that should not fail, no "for now".

**Write a regression test** that fails without the fix and passes with it. Run it both
ways and say so — a test that passes either way proves nothing. If `commands.test` is
null there is nowhere to put one: describe the manual repro check instead, and add
"no automated tests for this area" to discovered work.

Commit with `(refs #{n})`. Keep the checkpoint note current, per `/proof-work`.

## 6. Verify, keep the docs true, add the changelog line

- Run `verify.steps`; re-run the original reproduction and confirm it is gone. Surface
  `verify.manual` for the user — never claim a manual check.
- **Docs:** if the bug came from a doc being wrong, or the fix changes documented
  behaviour, fix the doc in the same change. Per the docs step in `/proof-work`.
- **Changelog:** per `_partials/changelog.md`, add a line under **Fixed** — the experience
  that was broken, and what it does now.

## 7. Learnings, PR, discovered work

- **Learnings:** the root cause is almost always a learning — it was invisible, or it
  would not have been a bug. Post a **Build** capture per `_partials/learnings.md`,
  written as a gotcha: the condition and the consequence. If the area keeps breaking,
  say that too; it is the most useful thing the record can hold.
- **PR:** as in `/proof-work`, with a **Root cause** section above the verification:
  what was wrong, why, and how the test proves it is fixed. Board → `in_review`.
- **Discovered work:** per `_partials/discovered.md`.

## Hand back

The PR URL, the root cause in one line, and the verification results — including what
still needs a human check.

Then **ask what to do next**, per `_partials/chain.md` — never start the next step unasked. The next link is the same as after
`/proof-work`: review.

## When it is on fire

If users are losing data, money is being taken wrongly, or the app is down: stopping the
harm comes first, and it is allowed to be a mitigation rather than a fix — turning a
feature off, reverting the change that caused it. Say clearly that it is a mitigation,
ship it through the normal PR, and **leave the issue open** for the root cause, which then
gets this whole process. A mitigation that quietly becomes the permanent fix is how the
same fire starts twice.
