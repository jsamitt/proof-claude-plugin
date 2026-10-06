# Decisions

Why Proof is built the way it is, and the traps found along the way. Each entry is
something that is invisible from the files and expensive to rediscover. Newest first.

Read this before changing the plugin's manifest, hooks or setup.

---

## 2026-10-06 — Specs carry user stories before acceptance criteria

**Decision:** `/proof-spec` writes a **User stories** section ("As a {specific user}, I
want {goal} so that {reason}") before the acceptance criteria, and every criterion must
serve a story. `/proof-work` and the reviewers receive the stories with the criteria.
**Why:** criteria say *what* must be true but not *for whom* or *why*. The reason is what
lets the build and the review judge a case the criteria did not foresee, and tying
criteria to stories exposes scope creep (a criterion serving no story) and gaps (a story
with no criterion).

## 2026-10-06 — /proof-init turns on the GitHub features Proof depends on

**Decision:** `setup-board.sh` checks that Issues and Discussions are on and that an
*Ideas* discussion category exists. Features that are off are reported as a decision, and
switched on with `gh repo edit` only after the user agrees (`--enable-repo-features`). A
missing category is walked through, since the API cannot create one. `/proof-spec` checks
before offering the Discussion landing and says when it is unavailable.
**Why:** Discussions are off on many repositories, so `/proof-spec`'s "park it as a
Discussion" option failed late, after the spec was written.
**Gotcha:** GitHub's GraphQL `hasDiscussionsEnabled` and REST `has_discussions` can briefly
disagree right after the setting changes. Re-read before concluding either way.
**Rejected:** turning features on silently. Discussions add a public tab on a public
repository, which is the owner's call.

## 2026-10-05 — Small designs are made in the spec; every design is recorded in the issue

**Decision:** `/proof-spec` can design a small visual change itself, on a Claude Design
canvas, using the project's design system. A design made in another tool goes through
`/proof-handoff`, which checks it against the code before anything is built and loops
with the design tool until nothing blocks. Whatever route a design takes, it is recorded
in the issue the same way (`_partials/design-record.md`): a frozen copy in the repo, one
row per state with its own acceptance criteria, components by their code names, and the
decisions made. `/proof-work` builds to it and the design reviewer checks against it.
**Why:** Designing in one tool and building in another makes the user the messenger,
checking twice by hand that the design can be built and that the build matches it. For
small changes the cheapest hand-off is none. For every change, "done" needs a fixed
target, or it means "close to the design".
**Rejected:** Attaching outside designs through `/proof-spec <n> <link>` with no check.
It records a design that may not be buildable, which moves the surprise from the design
to the build — the exact problem this exists to solve. Offering "design it here" without a design system: it produces a generic look that
quietly becomes the style.
**Gotcha:** Claude Design artboards are source files (`.dc.html`), so the frozen copy holds
exact values, not pictures. The canvas cannot be rendered to check it from the session, so
comparison works from the source.

## 2026-09-25 — New work is checked against existing work on the way in

**Decision:** `/proof-spec` starts by checking the idea against open issues, Discussions,
issues closed in the last 90 days and the decisions file, and settles every overlap,
supersession and contradiction in the session. `/proof-fix` and discovered work run a
duplicates-only version before filing. One shared partial, `_partials/overlap.md`.
**Why:** `/proof-plan --cleanup` only finds these after they are on the board, when the
context that would settle them has gone. At the door it is one question to someone who
has just been thinking about exactly this.
**Rule:** Settle at the start, apply at creation. Nothing about another issue changes
until the new one exists, so an abandoned spec leaves the board as it found it. In-flight
work is never closed, and a Discussion never supersedes an issue.
**Gotcha:** GitHub's built-in *Item closed* workflow moves every closed issue to the last
stage, so a duplicate closed by this check, by plan's cleanup or from the digest showed
up as **Shipped**. Anything closed without shipping is now archived off the board
(`board_archive`) in the same step.

## 2026-09-24 — The every-issue skills form a chain that always asks

**Decision:** spec → work → review → ship → learn (with `/proof-fix` in place of spec and
work for bugs). Each step ends by asking whether to continue to the next step for the
same issue, pick up a different issue, or pause. Nothing moves on unasked.
**Why:** The user should never have to remember what comes next, but must stay in
control of when: shipping in particular is often batched across several issues, and
merging a PR is always the user's call.
**Gotcha:** A learnings sweep can only see the session it runs in. Work and ship often
happen in different sessions, so `learn` as only the final link would miss the build
conversation, which is where most lessons are. So `learn` is the last link **and** is
offered whenever a chain pauses.

## 2026-09-24 — Learn owns what the project knows; retro owns how the work goes

**Decision:** `/proof-learn` handles individual lessons about the product and the code,
and the decisions file. `/proof-retro` handles patterns across many issues, and changes to
process and config. Learn never proposes process changes; retro never writes the
decisions file directly.
**Why:** Spotting repeated lessons had ended up in three places — learn's review, the
retro, and the nightly digest — each re-deriving it. Now a repeat is tagged once, the
moment it is found (a **🔁 Repeat of** comment), and the retro counts the tags rather than
re-reading everything. A retro finding that is really a lesson goes through the learning
durability gate instead of skipping it.

## 2026-09-24 — The guard judges what runs, not what is mentioned

**Decision:** The bash guard splits a chained command on `&&`, `||`, `;` and newlines,
sets aside parts that only record text (`git commit`, `log`, `show`, `diff`, `grep`,
`tag`, `notes`, `blame`), and checks everything else **together**.
**Why:** Matching the whole command as text refused a test that merely *mentioned* a
destructive database command, and would have refused a commit message describing one —
including the commit that added the rule. Checking the remaining parts together, rather
than one at a time, keeps SQL like `psql -c "SELECT 1; DROP TABLE x"` caught even
though the split lands inside the quotes.
**Rejected:** Checking each part separately — it misses exactly that SQL case.
**Gotcha:** Test the guard from a file (`tests/pre-bash-guard.test.sh`). A test written
inline in a shell command contains the very phrases it tests, and the live guard will
refuse the test itself.

## 2026-09-24 — Changelog lines are written with each change; ship only assembles them

**Decision:** `/proof-work` and `/proof-fix` add a line to `[Unreleased]` in the same PR
as the change. `/proof-ship` renames that section to the new version on a release branch
and opens it as its own PR, then deploys once that is merged.
**Why:** The base branch is protected, so a release cannot commit files at deploy time —
an earlier `/proof-ship` told itself to commit the version bump after deploying, which the
push guard would have refused. And an entry written while the change is fresh says *why*;
one reconstructed from commit messages at release time only says *what*.

## 2026-09-24 — Bugs get their own path

**Decision:** `/proof-fix` handles bugs instead of `/proof-spec` then `/proof-work`.
**Why:** Those two are built around something that should exist. A bug is something that
does not work, and the costly mistake is fixing the symptom — so the bug path demands a
reproduction and a proven root cause before any fix, stops after three wrong theories,
and requires a test that fails before the fix and passes after. Most releases of the
first project Proof was used on were bug fixes, so bugs needed a first-class path.

## 2026-09-24 — What GitHub's API can and cannot do to a project board

**Decision:** `setup-board.sh` automates everything the API allows, and `/proof-init`
walks the user through the rest one step at a time, re-running the script to confirm
wherever the API can read the result.
**Can:** set Status options (`updateProjectV2Field` with `singleSelectOptions`), link a
repo, add items, read workflows and whether each is enabled, and delete a workflow.
**Cannot:** create or enable a workflow (so *Auto-add to project* is manual), or read or
set the default repository (not in the schema at all).
**Gotcha:** `singleSelectOptions` replaces the whole option list. Options sent without
their existing `id` are recreated, and every card loses its status. Always send the IDs
back. Renaming a new board's Todo/In Progress/Done in place (same ID) also keeps the
built-in workflows pointed at the right stages.
**Gotcha:** `deleteProjectV2Workflow` on a built-in workflow is permanent. It disappears
from the list and the API cannot recreate it. Only do it on the user's explicit yes.

## 2026-09-24 — Scripts must run on macOS's stock bash 3.2

**Decision:** No `mapfile`/`readarray`, no associative arrays (`declare -A`), and no bare
`"${arr[@]}"` on a possibly-empty array under `set -u`. Use `while IFS= read -r` loops,
a `case` function for lookups, and `${arr[@]+"${arr[@]}"}`.
**Why:** `#!/usr/bin/env bash` on a Mac resolves to `/bin/bash` 3.2 unless the user has
installed a newer bash. `setup-board.sh` died on its first `mapfile`, so the board and
labels never got created. `stop-verify.sh` died the same way, so a project that turned
on `verify.on_stop` got **no verification at all, silently**.
**Gotcha:** Check with `/bin/bash -n` *and* a real run under `/bin/bash`. Syntax
checking passes while `mapfile` still fails at runtime.

## 2026-09-24 — Declare nothing in the manifest that lives in a standard folder

**Decision:** `plugin.json` holds only metadata. `skills/`, `agents/` and
`hooks/hooks.json` are all found automatically, and none of them is named in the
manifest.
**Why:** Twice now, naming a standard folder in the manifest broke the plugin in a way
validation did not catch. Listing agents as file paths loaded zero agents. Pointing
`hooks` at `./hooks/hooks.json` loaded the same file twice — one Claude Code version
accepted it silently, a newer one refused to load the plugin at all ("Duplicate hooks
file detected").
**Gotcha:** Different Claude Code versions check manifests differently. A plugin that
loads cleanly in one place can fail in another, so the real check is `claude plugin list`
showing **Status: enabled** on the machine that will actually use it.

## 2026-09-24 — Routines must be created on the Routines page, with repositories attached

**Decision:** `/proof-init` walks the user through creating the nightly routine at
claude.ai/code/routines rather than creating it with a scheduling tool.
**Why:** The scheduling tools available to a session cannot attach repositories or
connectors. A routine created that way started a session with no repositories, could not
read or post anything, and still reported a green, successful run. It was only caught by
checking for the digest.
**Gotcha:** A green run status means "did not crash", never "did the job". Always confirm
a routine by its output.

## 2026-09-24 — "Command not found" is not a failing test

**Decision:** The finish-line check (`stop-verify.sh`) treats exit code 127 as "could not
run" — a note, not a block.
**Why:** Fresh cloud workspaces do not have a project's packages installed. Treating the
missing test runner as a failure blocked every session from finishing, on every turn,
even when no code had changed.
**Rejected:** Installing dependencies inside the hook — slow, disk-hungry, and the wrong
job for a guard.

## 2026-09-24 — Let the plugin find `agents/` on its own

> **Superseded 2026-09-24** by *Declare nothing in the manifest that lives in a standard
> folder* — this is one case of that rule.

**Gotcha:** Listing agents in `plugin.json` as an array of file paths installs without
error, passes validation, and **registers zero agents**. The directory-string form does not
install at all. Leaving the `agents` key out and letting the default `agents/` folder be
discovered is the only form that loaded all four reviewers.
**Why it matters:** `/proof-review` would have run with no reviewers and nothing would
have said so. `claude plugin details proof` is the check — validation alone is not.

## 2026-09-24 — Quote the plugin path in hook commands

**Gotcha:** `${CLAUDE_PLUGIN_ROOT}` unquoted in `hooks.json` breaks on any machine whose
plugin path contains a space, and a hook that fails to start fails silently — every guard
simply stops running. Quote it: `"\"${CLAUDE_PLUGIN_ROOT}/scripts/hooks/x.sh\""`.

## 2026-09-24 — A `.gitignore` exception cannot reach inside an ignored folder

**Gotcha:** With `.claude/` ignored, `!.claude/harness.json` does nothing — git never looks
inside an ignored folder. Ignore the contents instead: `.claude/*` followed by the
exceptions. `/proof-init` fixes this when it sees it.

## 2026-09-23 — No project facts in the plugin

**Decision:** Every command, deploy step, board stage and risk area lives in each
project's `.claude/harness.json`. Skills say "run the project's test command", never a
specific command.
**Why:** The harness Proof was adapted from had its project baked into its skill text,
which made most of it inapplicable anywhere else.
**Rejected:** Per-project copies of the plugin — they diverge within weeks, and every fix
has to be made twice.
