---
name: proof-init
description: Use once per project — not part of every issue — when setting up the Proof harness for the first time, or when its configuration is out of date — inspects the repo, asks what it cannot infer, and writes .claude/harness.json plus the GitHub board and labels
---

# Initialise Proof on a project

Writes `.claude/harness.json` — the file every other Proof skill reads. Run once per
project. Re-run when commands, deploy steps or risk areas change.

```
/proof-init
/proof-init --refresh     # update an existing config, keep what is still true
```

Talk to the user per `_partials/voice.md` throughout.

## 1. Infer everything you can

Do the reading before the asking. The user should confirm, not dictate.

- `package.json` scripts (root and any sub-app), plus lockfiles and CI workflows —
  CI is the most reliable source of the *real* test command
- Existing project docs (`CLAUDE.md`, `README.md`, `CONTRIBUTING.md`) — often state
  the build, deploy and conventions outright
- Framework and platform signals: `app.json`/`eas.json`, `next.config`, `vite.config`,
  `Dockerfile`, `railway.json`, `vercel.json`, `fly.toml`
- Test files actually present — and be honest if there are almost none
- `.env` files and other secrets, for `protected_paths` (record the paths, never read
  the values)
- Whether a GitHub project board already exists for this repo

## 2. Ask only what you could not infer

One question at a time, each with your inferred answer as the default so the user can
confirm in a word. Cover, in order:

1. **What is this project, in a sentence** — and who uses it
2. **Commands** — present what you found; ask only about gaps
3. **How it gets shipped** — the real sequence, in order, including any manual steps
4. **Risk areas** — the brief for the risk reviewer. Ask directly: *what would be
   genuinely bad if it broke?* Payments, auth, user data, privacy/regulatory exposure,
   store compliance, anything irreversible. This answer does more for review quality
   than anything else in the config.
5. **Goals** — two to four things the project is trying to achieve right now, in plain
   words (*"Pass App Store review"*, *"Grow Plus sign-ups"*). Every priority rating will
   name the goal it serves, so these are worth a minute. Skip if the user has none yet;
   never invent them.
6. **Changelog and version** — if the repo has a changelog or a version file, confirm
   which files hold the version and which is the changelog. Look at the last release
   commit to see how they move together. Ask whether it ships to an app store that needs
   "What's New" text (`ship.store_notes`).
7. **Board** — stage names, or accept the defaults

Do not ask about anything you can see. Asking a user to type a command that is sitting
in their CI file is how a setup tool earns a reputation for being tedious.

## 3. Write the config

Copy `templates/harness.json` and fill it in. Rules:

- Run each command you record once, if it is safe and quick. A command that fails
  **today** can go in `commands`, but not in `verify.steps`. Otherwise every piece of work
  fails verification before it starts. Tell the user it fails and why.
- A command you are not sure about is `null`, not a guess. `null` means the skills skip
  that step and say so; a wrong command means they run something meaningless and pass.
- `verify.manual` holds checks only the human can do — simulator runs, device testing,
  visual checks. Skills surface these; they never claim them as done.
- `ship.steps` is an ordered list of `{name, run}`, optionally `{expect}` for a smoke
  test. Manual steps get `run: null` and are presented as instructions.
- `review.risk_focus` is prose, one concrete risk per line, in the project's own terms.

Show the finished config and **pause for approval** before writing.

## 4. Set up the board and labels

Only after the config is approved:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-board.sh"   # reads .claude/harness.json
```

The script lives in the plugin, not the project, so always call it by that path.

**It needs GitHub's command-line tool (`gh`), signed in with project access.** Cloud
sessions do not have `gh`. If you are in one, say so plainly, skip this step, and tell the
user to run `/proof-init --refresh` in Claude Code on their own computer. Do not report the
board as set up. Until it runs, priority labels do not exist, so anything that applies a
rating will have nothing to apply. If board creation fails on permissions, the fix is
usually `gh auth refresh -s project,read:project`. If the user would rather not, set
`board.enabled` to false. Labels alone still work.

### What the script does on its own

It is idempotent, so it's safe on a board that already has some of this.

- creates the board and links the repo
- sets the Status stage options from `board.stages`. A new board's *Todo / In Progress /
  Done* are renamed in place, so existing cards and GitHub's built-in workflows keep
  pointing at the right stages. Never set these options by any other route: sending
  options without their existing IDs wipes every card's status.
- adds every open issue that isn't on the board yet (the *Proof digest* issue stays off)
- creates the labels

### What needs the user: walk them through it, one step at a time

GitHub's API cannot do the steps below. The script flags each one with a tag. Go through
each flagged step **as its own exchange**: say what it's for in one line, give the link and
the exact clicks, then **wait for the user** before moving on. Do not batch them into one
list, and do not move to step 5 until each is done or explicitly skipped. Where the API
can confirm the result, **re-run the script and check**. The user saying "done" is not
confirmation.

1. **`DECIDE (done-workflows)`** — ask this first, because it is the only one you can
   finish yourself. The built-in *Item closed* and *Pull request merged* workflows move
   cards to the shipped stage when a PR merges or an issue closes, which is before
   `/proof-ship` has released anything. Offer three options:
   - **Remove them now** (recommended; Proof moves cards itself): re-run the script with
     `--remove-done-workflows`. Say plainly that this is **permanent**: GitHub's API
     cannot recreate built-in workflows.
   - **Turn them off by hand** (reversible): `<board>/workflows` → each one → toggle off.
   - **Keep them.**
2. **`ACTION NEEDED (auto-add)`**. Without it, only issues a Proof skill touches reach the
   board. Issues opened on the GitHub website or by other tools never do. Steps:
   `<board>/workflows` → *Auto-add to project* → Edit → Repository: this repo → Filter:
   `is:issue,pr is:open` → Save and turn on. Free accounts get one auto-add workflow.
   When the user says done, re-run the script and confirm it prints `auto-add workflow on`.
   If it doesn't, say what the script sees and go through it again.
3. **`CHECK (default-repo)`**: where *+ Add item* on the board creates issues. Steps:
   `<board>/settings` → Default repository → this repo. Nothing can read this setting,
   so ask the user to confirm it's set, and record that the confirmation is theirs.

If the user skips a step, note it as an open item in the hand-back (step 8).

## 5. Load Proof for anyone who opens the project

Write `.claude/settings.json` so Claude Code offers or loads Proof automatically, on the
user's computer and in cloud sessions:

```json
{
  "extraKnownMarketplaces": {
    "proof": { "source": { "source": "github", "repo": "jsamitt/proof-claude-plugin" } }
  },
  "enabledPlugins": { "proof@proof": true }
}
```

If the file already exists, **merge** these keys in. Never overwrite other settings.

Then check `.gitignore`. Both `.claude/harness.json` and `.claude/settings.json` must be
tracked. The common trap: a rule that ignores the whole `.claude/` folder **cannot** be
undone for a single file inside it. Git will not look inside an ignored folder, so a
`!.claude/harness.json` line after it does nothing. Replace the folder rule with one that
ignores the folder's *contents*:

```gitignore
.claude/*
!.claude/harness.json
!.claude/settings.json
```

Then verify with `git check-ignore` that both files are tracked and
`.claude/settings.local.json` is still ignored. Say what you changed.

The plugin repository is private. A new cloud session may not be allowed to download it
at startup. If `/proof-` commands do not appear in a cloud session, the user can add the
plugin repository to that session, or make the plugin repository public — it holds no
secrets or project details by design.

## 6. Seed the decisions file

If `learnings.file` does not exist, create it with a short header explaining what it is
and how entries get there. Do not backfill it with invented history.

## 7. Optional: the nightly digest

Ask whether the user wants a short digest posted after days they work on the project
(see `_partials/digest.md`). If not, skip this step.

If yes:

1. **The config and settings must be on the default branch first.** The nightly run
   clones the default branch. If steps 3–6 are on a feature branch, say so and wait for
   the merge before going further.
2. **Create the digest issue** titled **Proof digest**, with the body from the end of
   `_partials/digest.md`. Ask the user to **pin** it; that cannot be done from here.
3. **Fill in `templates/nightly-prompt.md`** with the project repository, the owner's
   GitHub login, their time zone, and the digest issue number. Show the finished prompt.
4. **The user creates the routine on the Routines page, not you.** Do not create it with a
   scheduling tool: those tools cannot attach repositories, and a routine without them
   runs, reports success, and does nothing. Walk the user through it:
   - Go to **claude.ai/code/routines** → **New routine**
   - Name it, paste the prompt
   - **Repositories:** add the project repository **and** `jsamitt/proof-claude-plugin`
   - **Trigger:** Schedule → Daily, at their chosen time. It is entered in local time and
     handles daylight saving
   - **Connectors:** keep GitHub if listed; remove the rest. A routine can use every tool
     it is given without asking
   - **Create**, then **Run now**
5. **Confirm it worked by the digest, not the status.** A green run only means it did not
   crash. Check the digest issue for a new comment. If there is none, the run's transcript
   (open it from the routine's page) says why.

## 8. Hand back

Report: the config path, what you inferred vs. what the user told you, the board URL,
and the one-line next step — `/proof-spec "<something you want to build>"`.

List anything from step 4 that is still open **first**: a skipped or unconfirmed
auto-add workflow or default repository, and the done-workflows decision if it was
deferred. Give the link for each.

Flag honestly anything that will limit the harness: no test command, an empty test
suite, no typecheck, no board permissions, a board not yet created because this was a
cloud session. The user should know where the safety net has holes before they rely on it.
