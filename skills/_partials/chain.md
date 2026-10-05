# The chain

Every issue moves through the same sequence, and each skill knows where it sits:

```
spec ─→ (handoff) ─→ work ─┐
                           ├─→ review ─→ ship ─→ learn
fix  ──────────────────────┘
```

`/proof-fix` replaces spec and work for bugs. `/proof-handoff` sits between spec and work
only for issues designed in another tool. Everything after is shared.

## At the end of every step: ask, never assume

When a step finishes, hand back its result, then **ask what to do next** — every time,
even when the answer seems obvious. Never start the next skill unasked: the user may want
to stop, switch, or batch several issues into one release.

Offer the options for this step (below), **put your recommendation first** with a
one-line reason, and keep the question short enough to answer in a word:

> **#{n} is ready for review.** What next?
> 1. **Review it now** — recommended: it is fresh, and review is quick
> 2. **Pick up a different issue**
> 3. **Pause here**

When the user picks the next step, invoke that skill **for the same issue or PR**, so it
does not ask again what to work on.

## Options at each step

| After | Recommended next | Also offer |
|---|---|---|
| `/proof-spec` → issue | **Build it** — `/proof-work {n}` | Spec another · Pick up a different issue · Pause |
| `/proof-spec` → issue to be designed elsewhere | **Design it** in your design tool from the brief, then `/proof-handoff {n} <link>` | Spec another · Pick up a different issue · Pause |
| `/proof-handoff` → design still blocked | **Revise the design** with the revisions note, then `/proof-handoff {n} <new link>` | Settle the blocking items as exceptions or spec changes · Pause |
| `/proof-handoff` → recorded | **Build it** — `/proof-work {n}` | Pick up a different issue · Pause |
| `/proof-spec` → Discussion | **Spec another**, or pick up an issue | Pause |
| `/proof-work` or `/proof-fix` → PR | **Review it** — `/proof-review {pr}` | Pick up a different issue · Pause |
| `/proof-review` with criticals | **Fix the criticals**, then re-review | Pause |
| `/proof-review` clean | **Ship it** — once the PR is merged, `/proof-ship` | Ship later with other changes: pick up a different issue · Pause |
| `/proof-ship` | **Capture learnings** — `/proof-learn` | Pick up a different issue · Pause |
| `/proof-learn` | **Pick up the next issue** | Pause |

Two things specific to shipping:

- **Merging is the user's call.** After a clean review, say the PR needs merging on
  GitHub first, and offer to run `/proof-ship` once they have. Never merge it yourself.
- **Shipping later is a real option, not a failure.** A release can carry several issues.
  "Ship later" moves on to the next issue and leaves this one in review.

## "Pick up a different issue"

Show the top three from `/proof-plan`'s ordering (finish in-flight work first, then
unblockers, investigations, neighbours, priority) — the recommendation only, without its
cleanup pass. Let the user pick one, then start the right skill for it: `/proof-work` for a
ready issue, `/proof-fix` for a bug, `/proof-spec` for anything not yet specced.

## "Pause here"

Before stopping, do two things:

1. **If work on the issue has started, update its checkpoint** (see `/proof-work`) so the
   next session resumes cleanly — from this machine or any other.
2. **Offer a learnings sweep** of this session, unless `/proof-learn` just ran. A lesson
   can only be swept from the session that had the conversation. If you pause after
   work and ship next week, the build conversation is gone by then. So `learn` is the
   last link in the chain, *and* the thing offered whenever a chain stops early.

Then stop. Nothing else runs until the user comes back.
