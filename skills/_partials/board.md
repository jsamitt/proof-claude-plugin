# Board updates

Board state is not bookkeeping you do if there is time — it is how the user sees what
is happening without reading the transcript. **Every stage transition updates the board
and the labels, in the same step, without being asked.**

Load stage names and the field name from `board.stages` / `board.field` in the config.
Never hardcode "In Progress" or "Status" — another project will name them differently.

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/board.sh"
board_init                       # resolves the project from board.name
ITEM=$(board_item <issue-number>) # adds the issue to the board if absent
board_set "$ITEM" "In Dev"        # value from board.stages
```

## Transitions

| When | Stage | Labels |
|---|---|---|
| Issue created, not yet specced | `backlog` | type label only |
| Spec being written | `spec_draft` | — |
| Spec approved | `ready` | +`ready`, +one P-label, +`investigate` if confidence is Low |
| Work starts | `in_dev` | +`in_progress`, −`ready` |
| PR opened | `in_review` | −`in_progress` |
| PR merged | `shipped` | — |
| Blocked, waiting on the user | unchanged | +`blocked` |
| Closed without shipping (duplicate, superseded, not planned) | off the board | −`ready`, −`in_progress` |

The `shipped` stage means **merged to the default branch**, not released — `/proof-ship`
is the separate release of already-merged work.

## The merge → Shipped move happens off-skill

The PR-merged → `shipped` transition is the one Proof cannot do in the moment: a merge
happens on GitHub, **outside any skill run**, so no skill is present to move the card.
Two mechanisms cover it, both set up by `/proof-init`:

1. **The GitHub "Pull request merged" Project workflow** (primary) moves the card to the
   `shipped` stage server-side the instant a PR merges — hands-free, every time. This is
   why `/proof-init` keeps that workflow on and pointed at the shipped stage (and removes
   only "Item closed", which misfires on every close).
2. **`board_reconcile`** (backstop) sweeps any item still at `in_review` whose issue is
   closed as completed and moves it to `shipped`. `/proof-ship` and `/proof-plan` call it,
   so drift self-heals on the next skill run — eventual, not instant, which is why the
   workflow is the primary fix.

```bash
board_reconcile    # after board_init; a no-op when nothing has merged
```

If issues keep sticking at `in_review` after you merge, the "Pull request merged" workflow
is off or mis-targeted — re-run `scripts/setup-board.sh` and follow its
`pr-merged-workflow` guidance.

## Closing without shipping

GitHub's built-in *Item closed* workflow moves **every** closed issue to the last stage,
so an issue closed as a duplicate would sit under `shipped` as if it had been built.
Whenever an issue is closed for any reason other than its work shipping, archive it off
the board as part of the same step:

```bash
board_archive "$(board_item <issue-number>)"
```

Archiving is not deleting: the item stays in the project's archive, and the issue itself
is untouched. Close first, then archive — if the workflow runs after the archive, it
only changes the stage of an item nobody sees.

## When the board is missing or off

If `board.enabled` is false, skip board calls entirely and keep the labels — they are
the cheap fallback and still make the issue list readable.

If `board.enabled` is true but the board cannot be found, **do not fail the run and do
not silently continue.** Finish the actual work, then say once, at the end: the board
named `<name>` was not found, run `scripts/setup-board.sh` to create it. Board
bookkeeping never blocks shipping code.
