# Priority — one rubric, used everywhere

`/proof-spec` sets the first rating; `/proof-plan` re-checks it as things change. Both
use this file, so a rating means the same thing whenever and wherever it was made.

## Three factors, three levels

Rate each **High, Medium or Low**. No numbers. A formula that multiplies three guesses
produces a figure like "3.2" that looks rigorous and is not — and false precision is
harder to argue with than an honest "medium".

| Factor | The question |
|---|---|
| **Value** | How much does this matter — to the people using the product, *and* to the project (revenue, less upkeep, unblocking other work)? One rating; the reason covers both sides, and names the **goal** it serves. |
| **Effort** | How much work, across product, design and engineering together? One rating; the reason says where it concentrates. |
| **Confidence** | How sure are we about the two ratings above? |

## Value is anchored to the project's goals

`goals` in the config lists what the project is trying to achieve right now — usually
two to four lines. Every value rating says which goal the work serves:

- **Serves a goal** — name it in the reason. This is what most High value looks like.
- **Serves no goal** — say so plainly. That is not automatically wrong: keeping the
  lights on, paying down risk, and fixing a bug users hit are all legitimate. But
  work that serves no goal and is not maintenance should rarely rate High. If it keeps
  coming up, the goals may be out of date — say that instead.

If `goals` is empty, rate value on its own merits and suggest setting goals once, in one
line. Do not invent goals on the user's behalf.

## Priority comes from value and effort

| | Low effort | Medium effort | High effort |
|---|---|---|---|
| **High value** | P1 | P1 | P2 |
| **Medium value** | P2 | P2 | P3 |
| **Low value** | P3 | P3 | **Reconsider** |

**Reconsider** is not a priority — it is a question. Say plainly that the work may not be
worth doing, and let the user decide whether to keep it at P3, park it as a Discussion,
or drop it.

## Confidence is not a discount

Value and effort are estimates. Confidence is how much those estimates can be trusted.
Do **not** let low confidence quietly push an issue down the list: that buries exactly
the issues where a little learning could change everything.

- **High** — nothing extra.
- **Medium** — name the unknowns in the reasoning.
- **Low** — still set the P-label from the table (it says what the priority *would* be if
  the guesses hold), **and** add the `investigate` label. Recommend a short, bounded look
  before committing to the work. What you find either confirms the rating or changes it —
  both are worth knowing early.

## Confidence is not risk of harm

"We don't know whether people will use this" is a confidence question. "This touches
purchases" is a risk question — and the risk reviewer handles it when the code is
reviewed. Keep them apart. Folding harm into priority counts it twice, and quietly
deprioritises important work just because it needs care.

## How to rate: propose, then adjust

Propose all three ratings in **one message**, each with a one-line reason, plus the
priority they produce. The user confirms or changes them in one reply. Never ask three
separate questions — rating is a judgment to check, not an interview to sit through.

Be willing to rate Low. An honest backlog is mostly P2 and P3. If everything is P1, the
ratings have stopped telling you anything.

## Where it lives

**Label** — exactly one of `labels.p1` / `p2` / `p3` from the config, plus
`labels.investigate` when confidence is Low. When a rating changes, remove the old P-label
in the same step; an issue with two P-labels is worse than one with none.

**Issue body** — a Priority section:

```markdown
## Priority: P1

| | Rating | Why |
|---|---|---|
| Value | High | Users asked for it in reviews; supports Pro sign-ups |
| Effort | Medium | Mostly design — two new screens; engineering is small |
| Confidence | High | Close to the existing freeze flow |

**Serves:** Grow Pro sign-ups
```

**When a rating changes**, update the label and the table together, and add a dated line
beneath the table saying what changed and why:

```markdown
_2026-10-02: P2 → P3 — #12 shipped and covers most of this._
```

The history is worth keeping. It shows how the thinking moved, which is often more
useful than where it landed.

## What does not get rated

- **Parked Discussions** — not commitments. Put a *provisional* rating in the body with
  no label; re-rate when it is promoted.
- **Parent issues** — the children carry the ratings.
- **Anything already In Dev or later** — the decision has been made. Re-rating it now is
  noise, unless the work has turned out to be something different from what was rated.
