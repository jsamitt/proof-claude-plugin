---
name: proof-learn
description: The last step of every issue, and whenever a working session pauses — sweeps the session for lessons about the product and code while the conversation still exists. Owns what the project knows: records a lesson directly, searches past decisions, promotes durable ones into the decisions file behind a durability gate, and keeps that file pruned. Part of every issue
---

# Learn

Direct access to the running record. The other skills capture learnings automatically;
this is for the ones that arrive on their own — debugging at midnight, a realisation in
the shower, a lesson from something that broke.

```
/proof-learn                   # sweep THIS session for anything worth keeping
/proof-learn "draft orders silently drop when a user signs out"
/proof-learn --search hints
/proof-learn --promote 14      # promote an issue's learnings to the decisions file
/proof-learn --review          # what is recorded, what should be promoted, what should be pruned
```

Read `_partials/config.md`, `_partials/voice.md` and `_partials/learnings.md` first — the format and the
promotion bar live there.

## Sweeping the session (no arguments)

The default. Re-read the conversation so far and find what is worth keeping — the point
is that you should not have to notice a learning in the moment to capture it.

If the session has been compacted, the full transcripts are in `.claude/archive/`
(written by the PreCompact hook before each compaction). Read the most recent ones so a
long session's early hours are not silently missing from the sweep.

### What to look for

Hunt these six patterns. They are where learnings actually hide:

- **A failed attempt followed by a different one that worked.** The learning is *why
  the first failed* — that is the part that will not be obvious next time.
- **A surprise.** Anything that behaved differently from what you or the user expected.
  Expectation-violations are the highest-value entries in the whole file.
- **A correction from the user.** "No, it actually works like…" means a wrong model was
  being carried, and almost certainly would be again.
- **Debugging that ended in a root cause.** Record the cause, not the fix. The fix is
  in the diff; the cause is nowhere.
- **A rejected alternative.** Something weighed and turned down, with a reason. This is
  the single most commonly lost piece of context on any project.
- **A constraint discovered the hard way** — a platform limit, an API that lies, a tool
  that silently no-ops.

Time is a reliable tell: **anything that took more than two attempts to get right was
teaching you something.** Go back and name it.

### What to ignore

These look like learnings and are not. Do not propose them:

- The task got done. That is the diff, not a lesson.
- A restatement of the requirements, the plan, or the approach.
- A transient environment failure — a flaky network call, a tool that timed out once.
  Unless it recurred and you found out why, it taught you nothing.
- General knowledge that happens to be true but was not learned *here*. If it did not
  come out of this project, it does not belong in this project's record.
- Anything already in `learnings.file`. **Check before proposing** — and if you find a
  near-duplicate, say so: it means the record was not read before the work started,
  which is more useful to know than the entry itself.

### Presenting the sweep

Propose candidates as a table, each with where it came from and your call on whether it
clears the durability gate in `_partials/learnings.md`:

```
From this session:

| # | Candidate | Source | Verdict |
|---|-----------|--------|---------|
| 1 | SecureStore writes >2KB no-op in Expo Go, succeed in a dev build | 40min debugging the profile switch | Durable — passes all four |
| 2 | Chose per-level AsyncStorage keys over one blob; one corrupt entry would lose everything | plan discussion | Durable — passes all four |
| 3 | patch-package step must run before the iOS build | build failure | Issue comment — fails Q3, it is in the postinstall script |

1 and 2 for DECISIONS.md, 3 as a comment on #14. Confirm?
```

**An empty sweep is a real answer.** If the session was routine, say "nothing from this
session meets the bar" and write nothing. Manufacturing entries to justify the run is
exactly how the file fills with noise and stops being read.

## Recording (when you name it yourself)

Ask which issue it belongs to. If none does, it goes straight to `learnings.file` as a
standalone entry.

Do not transcribe what the user said — interrogate it into something useful. If they
give you a decision, ask what the alternative was. If they give you a gotcha, get it
concrete enough to act on. *"AsyncStorage is unreliable"* helps nobody; *"AsyncStorage
writes over ~2KB fail silently in Expo Go but work in a dev build"* is the difference
between a record and a diary.

## Searching

Search issue comments under the learnings heading and `learnings.file` together, and
present what you find with links. If nothing matches, say so — do not reason from
general knowledge and present it as something the project learned.

## Promoting

Per the durability bar in `_partials/learnings.md`. Propose, wait for confirmation,
append, commit.

## Reviewing

Keeps the decisions file healthy. Two things:

1. **What has been captured recently**, and which candidates now clear the gate.
2. **What should be pruned** — entries about code that no longer exists, entries
   superseded twice over, entries that would fail question 3 today because the code
   caught up with them, and anything pushing the file past the size the partial
   recommends. Propose; never delete unasked.

If you notice repeats, tag any that are not yet tagged, per `_partials/learnings.md`.
Do not go further than that. Several repeats mean something about how the work is done
is off — that is a process question, and `/proof-retro` answers it.

## Hand back

After a **session sweep** — the chain's last link — report what was recorded, then ask
what to do next, per `_partials/chain.md`: usually, pick up the next issue.

The other modes (recording one lesson, searching, promoting, reviewing) just report their
result. They are not steps in an issue's chain.

## Where learn stops and retro starts

`/proof-learn` owns **what the project knows**: individual lessons about the product and
the code, and the decisions file that holds the durable ones. `/proof-retro` owns **how
the work goes**: patterns across many issues, and changes to process and config. Learn
never proposes process changes; retro never writes the decisions file directly.
