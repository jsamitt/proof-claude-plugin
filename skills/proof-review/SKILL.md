---
name: proof-review
description: Use when a pull request or working diff needs review — runs three independent reviewers (correctness, adversarial breaker, project risk) in parallel and posts consolidated findings. Part of every issue
---

# Review

Three reviewers, in parallel, on the actual diff. This is the only second opinion the
code will get, so it is deliberately adversarial — a review that mostly says "looks
good" has cost you time and bought nothing.

```
/proof-review 23        # a PR
/proof-review           # the current working diff
```

Read `_partials/config.md` and `_partials/voice.md` first.

## 1. Gather

The diff, the linked issue with its user stories and acceptance criteria, `project.docs`, and any
`learnings.file` entries touching these files. Reviewers judge against the criteria —
not against their own idea of what the feature should have been.

## 2. Dispatch

Spawn the agents named in `review.lenses`, in parallel, one message:

| Lens | Agent | Reviews |
|---|---|---|
| `correctness` | `proof-review-correctness` | Does it work, does it hold up, is it maintainable |
| `breaker` | `proof-review-breaker` | Actively tries to break it |
| `risk` | `proof-review-risk` | The project's own risk areas, from `review.risk_focus` |
| `design` | `proof-review-design` | Design-system adherence and platform accessibility |

Pass each: the diff, the user stories and acceptance criteria, relevant docs, and the lens-specific
context — `review.risk_focus` verbatim to the risk reviewer, the whole `design` block to
the design reviewer, plus the issue's `## Design` section and the path to its frozen copy
when there is one (`_partials/design-record.md`). Reviewers read and report. **They never edit.**

**Skip the `design` lens when the diff has no UI.** It is also worth running with no
design system wired, but expect a thinner review — it will say so itself and fall back
to accessibility. If that happens twice, run `/proof-design`.

Each returns:

```json
{"lens":"...","findings":[{"severity":"critical|warning|note","file":"","line":0,
 "finding":"","recommendation":"","evidence":""}],"summary":""}
```

## 3. Consolidate

Merge in your own reasoning, not via another agent. Drop duplicates on file + line +
substance. Then apply the bar:

> **Critical** = you would not ship this. It breaks a stated criterion, loses or
> corrupts data, exposes something that must not be exposed, or fails on an input a
> real user will produce. Everything else is a warning or a note.

Before emitting any critical, try to disprove it — read the surrounding code and check
whether something already handles it. A reviewer that cries wolf gets ignored within a
week, and then the whole gate is theatre. Findings with a reproduction attached skip
this: a failing test is its own proof.

## 4. Post

One comment per lens, then a summary table:

```markdown
| Lens | Critical | Warnings | Notes |
|---|---|---|---|
| Correctness | 0 | 2 | 1 |
| Breaker | 1 | 0 | 2 |
| Risk | 0 | 1 | 0 |
| Design | 0 | 3 | 1 |

**Verdict:** {Ship it | Fix first}
```

Write the verdict and each lens summary per `_partials/voice.md` — lead with what a
finding means for the people using the product. Keep each finding's technical detail
exact underneath; a vague finding cannot be fixed.

**Only criticals block.** Warnings and notes are recorded and do not gate — a review
that blocks on style is a review you will start skipping.

## 5. Fixing

If the user asks you to fix the findings: fix the criticals, plus warnings that are
plainly right and cheap. Push, then re-review — and pass the previous findings through
so the second pass checks your fixes and looks at what changed, rather than starting
over and generating a fresh crop of opinions.

**Two rounds, then stop.** If criticals survive two rounds, the disagreement is real and
needs you, not a third round of the same argument.

## 6. Learnings

Per `_partials/learnings.md`, capture anything from the review worth remembering beyond
this fix — especially a finding that a past learning should have prevented. That is the
signal the record is not being read before work starts.

## Hand back

The verdict, the criticals in one line each, and what you fixed versus what you left.

Then **ask what to do next**, per `_partials/chain.md` — never start the next step unasked.
