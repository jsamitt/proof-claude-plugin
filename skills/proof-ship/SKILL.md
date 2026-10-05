---
name: proof-ship
description: Use when merged work needs to go out — prepares the release (version, changelog, app-store notes) as its own pull request, then runs the project's preflight and deploy steps in order, halting on the first failure, and closes out the board. Part of every release
---

# Ship

Runs `ship.preflight` and `ship.steps` from the config, in order, stopping at the first
failure. It knows nothing about your infrastructure — the project's config does.

```
/proof-ship
/proof-ship --dry-run     # show what would run, run nothing
```

Read `_partials/config.md`, `_partials/voice.md` and `_partials/changelog.md` first.

Shipping has two phases, because the base branch is protected: the version bump and the
changelog must arrive through a pull request like everything else. So `/proof-ship`
**prepares the release as a PR**, you merge it, and then `/proof-ship` again **deploys**.
It works out which phase it is in by itself.

## 0. Prepare the release

Skip this step if `ship.changelog` is null and `ship.version_files` is empty.

**Already prepared?** If the newest changelog heading is a version rather than
`[Unreleased]`, and every version file already says that version, the release is ready —
go to step 1.

Otherwise:

1. **Collect what is going out:** the `[Unreleased]` entries, and every PR merged since
   the last release. If a merged PR that changed behaviour has no entry, write one now per
   `_partials/changelog.md` — then say it was missed, because it should have been written
   with the change.
2. **Propose the version.** Follow the scheme the project already uses: read the last
   few changelog headings, and look at the last release commit to see **how the version
   files moved together** — do the same. Fixes only usually means the smallest bump;
   new capability, the next one up. Say which you picked and why, and **wait for a yes** —
   a version number is public and permanent.
3. **Write it on a branch** `release/{version}` from `branch.base`: rename `[Unreleased]`
   to `[{version}] - {date}`, bump each file in `ship.version_files`, and nothing else.
4. **If `ship.store_notes` is true**, draft the app store's "What's New" text per
   `_partials/changelog.md`.
5. **Open the PR** titled *Release {version}*, with the changelog section and the store
   text in the description. Then stop: ask the user to merge it and run `/proof-ship`
   again to deploy.

## 1. Preflight

Work through `ship.preflight`. Automated items you run; manual items you **present and
wait on** — do not tick a box on the user's behalf.

Also check, before anything leaves the machine:

- Working tree clean, on `branch.base`, up to date with the remote
- The changes going out are merged, and nothing unmerged is about to ship by accident
- `verify.steps` pass right now — not "passed in CI yesterday"
- If step 0 applied, its release PR is merged and the version on the base branch is the
  one being shipped

## 2. Confirm

Show what is about to go out — the commits, the version, and the ordered steps — and
**wait for a go-ahead.** Deployment is the one irreversible thing this harness does;
it always asks, including under autonomous settings.

## 3. Run the steps

In order. For each: announce it, run it, show real output.

- A step with `expect` is a smoke test — compare and halt on mismatch
- A step with `run: null` is manual: present the instruction and wait
- **On any failure, stop.** Report what failed, what already ran, and what that leaves
  half-deployed. Never continue past a failed step hoping the next one fixes it, and
  never retry a deploy command automatically.

## 4. Close out

Board → `shipped` for everything in this release. Comment the release, with its
version, on each issue.

If there is store text, present it again now, ready to paste into the store's console —
this is the moment it is needed. Nothing is committed here: the release PR already
carried every file change.

## 5. Learnings

Per `_partials/learnings.md`, capture the **Ship** entry: anything that behaved
differently in the real environment, any step that needed a manual fix, anything that
should change in `ship.steps` next time. Deploy surprises are the most expensive kind
to rediscover, and the easiest to forget once it is working again.

If a step needed hand-holding twice, propose fixing the config rather than living
with it.

## Hand back

What shipped, what version, where it landed, and anything still needing a human — the
store text to paste, a store review to watch, a smoke test only they can run.

Then **ask what to do next**, per `_partials/chain.md` — never start the next step unasked. After a ship, the recommended next step is `/proof-learn`.
