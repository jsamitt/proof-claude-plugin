# Builder — who builds an approved plan, and on which model

`/proof-work` and `/proof-fix` pin Opus in their frontmatter, so the first reply, the one
that makes the plan, runs on Opus. A revision of the plan, and everything after approval
(relaying questions, running checks, escalating, the PR), runs on the session's model:
a skill's model lasts one turn. The build is where most of the cost is, and most builds
do not need Opus. So the plan ends with a recommended builder model, the developer picks
one when they approve, and the build runs in the `proof-builder` agent on that model.

## 1. Recommend a builder

End the plan (or the proposed fix) with one line:

> **Recommended builder: Sonnet** — 3 files, no declared risk areas, lint and build will
> catch slips. Reply `approve` to use it, `approve, opus` (or `haiku`) to pick another,
> or `approve, here` to build in this session.

Pick from what you already know after planning:

| Recommend | When |
|---|---|
| **Opus** | **Any** of: the plan touches a `review.risk_focus` area; the issue has `labels.investigate`; the plan changes more than five files or crosses several parts of the codebase; something on the plan's unsure list is hard to undo |
| **Haiku** | **All** of: two files or fewer; copy, content or config only, with no new logic; no risk area; no `## Design` section; `verify.steps` is not empty, so something will catch a slip |
| **Sonnet** | Everything else |

Two more signals each raise **Haiku to Sonnet**, and raise **Sonnet to Opus** when the
plan also spans more than three files: a **P1** (a mistake costs more) and a **design
record with three or more states** (more to match). The reason names the signals that
decided it.

Then apply the floor, `models.builder_min`. Missing or `null` means no floor. A value
other than `haiku`, `sonnet` or `opus` is ignored: say once that it is not a model and
there is no floor. Never recommend below a valid floor, and say so when it raised the
pick: *"Sonnet by the rules; Opus because this project's minimum is Opus."*

**When `verify.steps` is empty**, nothing will check the build, so say that in the line
(*"nothing will verify this build"*) and never recommend below Sonnet.

No token or cost estimates. A number here would look precise and be a guess.

**Under `--guided`**, the build stops after every criterion, so it runs in this session.
Replace the line with *"Guided: building in this session."* and offer no model choice.

## 2. Read the approval

Read the reply **by intent**, not by exact words:

| Reply | Builder |
|---|---|
| Any clear yes with no model and no "here": `approve`, "yes", "looks good", "go ahead", "lgtm" | The recommendation |
| A clear yes naming one model: `approve, opus`, "go ahead on sonnet", "Approve, Haiku." | That model |
| A clear yes saying to build here: `approve, here`, "build it here" | No builder. Build in this session on the session's model, exactly as the skill's build step describes |
| A yes that names two models, negates one ("not opus"), or names something that is not haiku, sonnet or opus | Ask one short question to settle it; do not guess |
| A request to change the plan, or a question about it | Revise or answer, then ask again |
| No clear yes ("wait", "not yet", "let me think") | Nothing is built. Wait |

**Under `--guided`**, every approval builds in this session: ignore a model name or
"here" in the reply, say once that guided builds run here, and record the builder as
`here`.

**When `verify.steps` is empty** and the developer picks Haiku, say once that nothing
will check a Haiku build here, and go on with their pick.

A pick below `models.builder_min`, or `here` when the floor is above the session's model,
is the developer's call. Say once that it is below the project's minimum, and go on.

**Write the checkpoint now**, before anything is built, per section 5, with the builder
just chosen, *Done: none* and *Next:* the first criterion. A first build that is
interrupted then still leaves something to resume from.

## 3. Hand off to the builder

Spawn `proof-builder` with the chosen model passed as the spawn's model override. Its
own frontmatter says `inherit`, so the override is what sets it. **Run it in the
foreground** and wait for it to finish: verification and the next step depend on its
result, and checks run against a half-built branch prove nothing. If the spawn ran in the
background anyway, wait for its completion before doing anything else with the branch.
Keep its agent id for this session; it is how you continue it (section 4).

Pass it the brief its definition lists:

- the issue: user stories, acceptance criteria, out of scope
- the approved plan, word for word
- the branch, checked out
- the config path, `project.docs`, and decisions that touch this area
- `protected_paths`, verbatim
- **with a design:** the issue's `## Design` section, the path to its frozen copy, and the
  `design` block from the config (tokens, rules, platform)
- **for `/proof-fix`:** the proven root cause and the reproduction, with the criteria to
  report against: *the fix removes the cause* and *a regression test fails before the fix
  and passes after*
- **when resuming:** what is done (reconciled with `git log`, section 5) and what is next

Tell the developer in one line what is happening: *"Building on Sonnet. Its step-by-step
work is in the builder's own transcript; I'll report when it's done or needs you."*

## 4. Handle what comes back

The builder ends with a JSON report (`status`: `done`, `question` or `blocked`). After
each report, update the checkpoint from it.

**Check the report before trusting it.** If there is no JSON object, it does not parse, or
`status` is none of the three, look at `git log {branch.base}..HEAD` and `git status`,
treat the build as unfinished, and continue the builder once: *"Finish, commit, and end
with the JSON report."* A second bad report goes to the skill's *If it goes wrong* path.
The same applies to a `question` with no question in it.

**`question`** — ask the developer, framed per `_partials/voice.md`, with the builder's
options and recommendation. Then **continue the same builder** with the answer: send it a
message by the agent id you kept, so it keeps its context and its model. Only if it can
no longer be reached (a new session, or it has ended for good) spawn a fresh builder on
the same model with the brief, the commits so far, what is done and next, and the answer,
and tell the developer in one line that the builder's working context was lost. A
question never counts as a fix attempt.

**`blocked`** — follow the skill's *If it goes wrong* path.

**`done`** — first check `criteria`: every one must be `done`. If any is `partial` or
`not started`, the build is not done. Continue the builder to finish it, and treat a
second short report as *If it goes wrong*. Never let passing checks stand in for an
unmet criterion. Then run every command in `verify.steps` **yourself**, in this session,
and report the real output. The builder may have run them; its word is not the check.
If `verify.steps` is empty, say plainly that nothing verified this build, and carry that
into the PR.

- **All pass** → go on to the skill's next step.
- **Something fails** → send the failing command and its output back to the builder to
  fix. Each send is one **fix attempt**.
- **Any builder gets two fix attempts.** If it is still failing after two:
  - **not Opus** → escalate: spawn a fresh `proof-builder` on **Opus** with the brief, the
    branch as it now stands and the failing output. Do not pause to ask. Tell the
    developer in one line, and record it for the PR's Notes: *"Escalated from Sonnet to
    Opus after two failed fix attempts on `lint`."* The Opus builder then gets its own
    two attempts.
  - **already Opus** (chosen, recommended, or escalated) → the skill's *If it goes wrong*
    path.

Keep the builder's `notes` for the PR's Notes, its `learnings` for the skill's Build
learnings capture, and its `discovered` items for the discovered-work step.

## 5. Checkpoint and resume

The checkpoint comment carries one extra line, written at approval and kept current:

```markdown
**Builder:** sonnet · fix attempts 1/2      ← or opus, haiku, here; "sonnet → opus (escalated) · fix attempts 0/2"
```

It also links the approved plan. At approval, post the plan the developer approved as
its own comment headed `### 📋 Approved plan` (for `/proof-fix`, with the root cause and
the reproduction), and put its link in the checkpoint. A resumed builder needs the plan,
and a checkpoint's *Done* and *Next* are not the plan.

On a resume:

- **Reconcile first.** Compare *Done* with `git log {branch.base}..HEAD`. A builder can
  commit after its last report, so trust the commits, and update the checkpoint before
  going on.
- **Builder is a model** → spawn a fresh builder on that model (the earlier one is gone)
  with the full brief from section 3, the approved plan from its comment, and the
  reconciled *Done* and *Next*. Keep the attempt count from the checkpoint. After an
  escalation, resume on Opus.
- **Builder is `here`** → build in this session. Nothing is spawned.
- **No Builder line** (a checkpoint from before this existed) → it has no plan comment
  either. Rebuild the plan from the issue's criteria and the branch's commits, show it in
  a few lines, and ask once which builder to use, with a recommendation per section 1.
  Post the rebuilt plan as the `### 📋 Approved plan` comment and write the Builder and
  Plan lines before building.

## 6. In the PR

Under **Notes**, say which model built it, and any escalation: *"Built by Sonnet."* or
*"Built by Sonnet; escalated to Opus after two failed fix attempts on `lint`."* Built
here: *"Built in the main session."* If nothing verified the build, say that too.
