# Discovered work — collect, never file

Work you find while doing other work is the main way a solo backlog grows, and the
main way a run goes off the rails. The rule is absolute:

> **Collect it. Present it at the end. File only what the user approves.**

Never open an issue mid-run. Never widen the current issue to absorb something you
found. Never fix "while I'm in here" — if it is not in the acceptance criteria, it is
discovered work, even when the fix is two lines.

## Collecting

Keep a running list as you go. For each item capture: what it is, where you hit it
(file, or the step you were on), and why it is out of scope for the current issue.

## Presenting

Before presenting, run the light overlap check in `_partials/overlap.md` on each item.
Something already tracked is not new work, however new it felt when you found it.

At the end of the run — after the PR is open, before you hand back — present the list
as a table with a recommended call for each:

```
Discovered while working #{n}:

| # | What | Where | Recommendation |
|---|------|-------|----------------|
| 1 | Draft orders are lost when a user signs out mid-checkout | cart.ts | File — real data loss path |
| 2 | Currency formatting duplicated between two files | format.ts | Note in decisions — cleanup, no user impact |
| 3 | Tests use a hardcoded user id | orders.test.ts | Drop — it is a fixture, working as intended |
| 4 | Receipt screen ignores the refund flag | receipt.tsx | Already tracked as #19 — add the refund case there |

Which should I act on? (numbers, "all", or "none")
```

Four dispositions, and say which you recommend and why:

- **File** — a real problem or a genuinely wanted change. Becomes an issue.
- **Already tracked as #n** — an open issue covers it. If the finding adds something
  that issue does not say, offer to add it there as a comment; otherwise nothing to do.
- **Note** — worth remembering, not worth an issue. Goes to the learnings record.
- **Drop** — looked like a problem, is not. Say so; do not file defensively.

Recommend **Drop** freely. A backlog full of things you will never do is noise, and
noise is what makes a board stop being useful.

## Filing (only what was approved)

For each approved item, create an issue with the `discovered` label from the config,
a one-line body saying it was found while working the parent issue, and a link back.
Place it at the `backlog` stage on the board. For an approved **Already tracked** item,
add the comment to the existing issue instead. Then report the new issue numbers and
the comments added.

Items the user did not pick are not filed, not re-raised, and not mentioned again.
