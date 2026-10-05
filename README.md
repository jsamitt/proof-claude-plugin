# Proof

A Claude Code development harness for **solo builders**. Spec → build → review → ship,
with a running record of why the thing is built the way it is.

Most AI development harnesses are team harnesses: staged handoffs, review boards,
parallel work queues. Those solve coordination problems. Working alone you do not have
coordination problems — you have **memory problems and second-opinion problems**. Proof
keeps the parts that address those and drops the rest.

## Install

```bash
claude plugin marketplace add jsamitt/proof-claude-plugin
claude plugin install proof@proof
```

Then, in any project, **on your own computer**:

```
/proof-init
```

It reads the repo, asks what it cannot infer, and writes `.claude/harness.json`. It also
adds a project settings file so Claude Code offers Proof to anyone who opens the project,
creates the GitHub board and labels, and optionally sets up the nightly digest.

Run it on your computer rather than in a cloud session: creating the board and labels
needs GitHub's command-line tool, which cloud sessions do not have.

### Updating

```bash
claude plugin update proof@proof
```

Then restart Claude Code. Cloud sessions and the nightly digest download a fresh copy
each time, so they need nothing.

### Cloud sessions

This repository is private, so a new cloud session may not be allowed to download Proof
at startup. If the `/proof-` commands are missing, add this repository to the session, or
make it public — it holds no secrets or project details by design.

## Commands

**Every issue, in order.** Each step ends by asking whether to go on to the next one for
the same issue, pick up a different issue, or pause. Nothing moves on unasked.

```
spec ─→ work ─┐
              ├─→ review ─→ ship ─→ learn
fix  ─────────┘   (bugs take /proof-fix instead of spec and work)
```

| Command | What it does |
|---|---|
| `/proof-spec "<idea>"` | Checks what it overlaps, supersedes or contradicts, and settles each → acceptance criteria and a priority rating, then asks: a board-tracked **issue**, or a parked **Discussion**? |
| `/proof-work <issue>` | Plan → *you approve* → build, verify, keep docs true, PR. Pauses again only for a decision the plan did not anticipate. Resumes from its checkpoint if interrupted |
| `/proof-fix "<symptom>"` | For bugs: reproduce → root cause, proven → *you approve* the fix → fix with a test that fails before and passes after → PR |
| `/proof-review [pr]` | Reviewers on the diff: correctness, breaker, project risk, and design where there is UI |
| `/proof-ship` | Prepare the release (version, changelog, app-store notes) as a PR; once merged, run the preflight and deploy steps in order, halting on failure |
| `/proof-learn` | **What the project knows.** Sweep the session for lessons about the product and code; search, promote and prune the decisions file. The last step of every issue, and offered whenever you pause, since only the session that had the conversation can sweep it |

**When a situation calls for it** — not part of every issue:

| Command | What it does |
|---|---|
| `/proof-init` | Configure Proof for a project; create the board and labels. Once per project |
| `/proof-plan` | What to work on next, in what order; re-check stale priorities; optional cleanup. Applies anything you ticked in the digest first |
| `/proof-retro` | **How the work goes.** Monthly or after a release: shipped against plan, where work waited, estimates against reality, what keeps breaking, how often lessons repeated, whether goals moved. At most three process changes |
| `/proof-design` | Establish a design system, wire it so the other skills obey it, or report drift |

## The one rule

**Proof contains no project facts.** Every command, deploy step, board stage and risk
area lives in `.claude/harness.json` inside each project. Skills say "run the project's
test command", never `npm test`.

This is the whole reason it is reusable. A harness with the project baked into its
instructions is not a harness — it is that project, written as one — and it breaks the
moment you point it at something else.

```jsonc
{
  "commands":  { "test": "npm test", "typecheck": "npm run typecheck" },
  "verify":    { "on_stop": true, "steps": ["test"],
                 "manual":  ["Run the changed flow on a phone-sized screen"] },
  "board":     { "name": "My App", "field": "Status",
                 "stages": { "in_dev": "In Dev", "in_review": "In Review" } },
  "review":    { "risk_focus": ["Checkout must never charge twice",
                                "Users can only read their own workspace's data"] },
  "design":    { "tokens": "src/theme.ts", "platform": "web",
                 "rules":  ["Use spacing tokens, never raw pixel values"] },
  "ship":      { "steps": [ { "name": "Deploy API", "run": "npm run deploy" } ] }
}
```

A `null` command means *this project does not have one* — the step is skipped and said
so out loud. Proof never guesses a command from the file tree.

## What it does automatically

- **Board and labels** move on every transition, without being asked
- **Learnings** are captured at four points — spec, build, review, ship — as issue
  comments under a fixed heading, so they are searchable later. `/proof-learn` also
  sweeps a whole session on demand, so you do not have to notice a lesson in the moment
  to keep it. Promotion to the decisions file is gated on four questions and your
  confirmation, because that file is read at the start of every spec and every build —
  a weak entry there costs attention forever
- **Nothing new duplicates something old.** Before a spec starts, it is checked against
  open issues, Discussions, recently closed issues and the decisions file. Overlaps,
  supersessions and contradictions are settled in the session, and the changes to other
  issues are applied only when the new one is created. Bugs and discovered work get a
  lighter duplicate check before anything is filed
- **Discovered work** is collected during a run and presented at the end with a
  recommendation for each item. Nothing is filed without your approval
- **Priority** is rated at spec time on value, effort and confidence — High/Medium/Low,
  never a fake-precise score. Stored as a `P1`/`P2`/`P3` label, with the reasoning in the
  issue body. Low confidence adds `needs-investigation` rather than quietly lowering the
  priority, because those are the issues where a little learning changes the most
- **Goals** anchor priority. The config lists what the project is trying to achieve
  now; every value rating names the goal it serves, and `/proof-plan` flags work that
  serves none — and goals nobody is working on
- **The changelog** gets a line with each change, in the same PR, while the reason is
  fresh. `/proof-ship` turns those into the release, and drafts app-store "What's New"
  text for the people who use the app
- **Docs stay true.** Before each PR, `/proof-work` checks whether the change made the
  project's docs wrong, and fixes the facts in the same PR
- **Plain language by default.** Everything you read leads with what changes for users,
  then cost, then risk, then technical detail — plain on top, exact underneath

## What it deliberately does not do

No *mandatory* idea tier, no epic workflow stage, no parallel work swarm, no review of
documents before code exists, no rehearsal review before the real one. Each of those
exists to move information between people. Alone, they cost time and buy nothing.

Two things survive in smaller form, because they earn it solo for different reasons
than they did on a team: a **Discussion** is offered as a place to park a worked-out
concept *off* the board, and oversized work can split into a **parent with native
sub-issues** — both decided inside `/proof-spec`, neither a stage anything must pass
through.

## The nightly digest

Optionally, a scheduled run posts a short digest after days you worked on the project —
what moved, what to pick up next, and a few calls to make, each a checkbox. Tick them on
your phone; they are applied that night, or immediately if you run `/proof-plan`. Quiet
days post nothing. The nightly run proposes and applies what you ticked; it never
decides anything itself.

`/proof-init` sets it up and walks you through it. Two things to know:

- **Create the routine on the Routines page (claude.ai/code/routines), with both the
  project repository and this one attached.** Claude's scheduling tools cannot attach
  repositories, and a routine without them runs, reports success, and does nothing.
- **A green run status only means it did not crash.** Confirm it worked by the digest
  appearing on the project's Proof digest issue.

## Guardrails

Four hooks, all cheap, all on by default except the last:

| Hook | Blocks |
|---|---|
| Bash guard | **Refuses** `rm -rf` on a root, force-push, push straight to main, `reset --hard`, writing `.env`, wiping a remote database, `DROP DATABASE`. **Asks you** before dropping or emptying a table, deleting every row, pushing migrations to the live database, or discarding uncommitted work |
| Write guard | Secrets, keys, lockfiles, and anything in `protected_paths` |
| Verify on stop | Finishing while `verify.steps` fail (opt-in per project) |
| Compaction archive | Nothing — it saves the transcript before it is summarised |

Database rules only fire when a database tool is actually run, and a commit message
that *mentions* a dangerous command is not refused — but a dangerous command chained after
one still is. The cases live in `tests/pre-bash-guard.test.sh`.

Guards are narrow on purpose. One that fires on ordinary work gets switched off, and
then it guards nothing.

## Layout

```
.claude-plugin/    plugin.json, marketplace.json
skills/            the ten commands, plus _partials/ shared by them
agents/            the four reviewers
hooks/             hooks.json
scripts/           board.sh, setup-board.sh, hooks/
templates/         harness.json (per-project config), nightly-prompt.md (routine prompt)
tests/             regression cases for the guards
DECISIONS.md       why Proof is built the way it is, and the traps found along the way
```

## Changing Proof itself

Changes go through a branch and a pull request. Proof's own guard blocks pushes straight
to `main` — including from a session working on Proof.

Before merging, install the branch and check that everything loads:

```bash
claude plugin validate .claude-plugin/plugin.json
claude plugin marketplace add /path/to/your/checkout && claude plugin install proof@proof
claude plugin details proof     # expect 10 skills, 4 agents, 3 hook events
bash tests/pre-bash-guard.test.sh   # expect 0 failed
claude plugin list              # expect "Status: enabled" for proof
```

Validation passing is not enough on its own, and neither is one machine: Claude Code
versions check plugins differently. Keep `plugin.json` to metadata only — see
`DECISIONS.md` for the two times naming a standard folder broke the plugin.

