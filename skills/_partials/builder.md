# Builder — who builds an approved plan, and on which model

`/proof-work` and `/proof-fix` plan on Opus: their frontmatter pins it, and everything up
to the approval pause is one turn. The build is where most of the cost is, and most
builds do not need Opus. So the plan ends with a recommended builder model, the
developer picks one when they approve, and the build runs in the `proof-builder` agent on
that model. Planning, approval, verification and the PR stay in the main session.

## 1. Recommend a builder

End the plan (or the proposed fix) with one line:

> **Recommended builder: Sonnet** — 3 files, no declared risk areas, lint and build will
> catch slips. Reply `approve` to use it, `approve, opus` (or `haiku`) to pick another,
> or `approve, here` to build in this session.

Pick from what you already know after planning:

| Recommend | When |
|---|---|
| **Opus** | **Any** of: the plan touches a `review.risk_focus` area; the issue has `labels.investigate`; the plan changes more than five files or crosses several parts of the codebase; something on the plan's unsure list is hard to undo |
| **Haiku** | **All** of: two files or fewer; copy, content or config only, with no new logic; no risk area; `verify.steps` is not empty, so something will catch a slip |
| **Sonnet** | Everything else |

The reason names the signals that decided it. Then apply the floor: if
`models.builder_min` is set, never recommend below it. Say so when it raised the pick:
*"Sonnet by the rules; Opus because this project's minimum is Opus."*

No token or cost estimates. A number here would look precise and be a guess.

## 2. Read the approval

| Reply | Builder |
|---|---|
| `approve` | The recommendation |
| `approve, opus` / `sonnet` / `haiku` | That model. Below `models.builder_min` is allowed, because the developer chose it; say once that it is below the project's minimum, and go on |
| `approve, here` | No builder. Build in this session on the session model, exactly as the skill's build step describes |

Anything else is a change to the plan: revise it and ask again.

## 3. Hand off to the builder

Spawn `proof-builder` with the chosen model passed as the spawn's model override. Its
own frontmatter says `inherit`, so the override is what sets it. Wait for its result.
Pass it the brief its definition lists: the issue, the approved plan, the branch, the
config path, `project.docs`, relevant decisions, and for `/proof-fix` the root cause and
reproduction.

Tell the developer in one line what is happening: *"Building on Sonnet. Its step-by-step
work is in the builder's own transcript; I'll report when it's done or needs you."*

## 4. Handle what comes back

The builder ends with a JSON report (`status`: `done`, `question` or `blocked`). After
each report, update the checkpoint from it.

**`question`** — ask the developer, framed per `_partials/voice.md`, with the builder's
options and recommendation. Then continue **the same builder** with the answer, so it
keeps its context. If continuing it is not possible in this session, spawn a fresh
builder on the same model with the brief, the commits so far, what is done and next, and
the answer.

**`blocked`** — follow the skill's *If it goes wrong* path.

**`done`** — run every command in `verify.steps` **yourself**, in this session, and
report the real output. The builder may have run them; its word is not the check.

- **All pass** → go on to the skill's next step.
- **Something fails** → send the failing command and its output back to the builder
  (the same one, or a fresh one as above) to fix. That is one **fix attempt**.
- **Still failing after two fix attempts by a builder that is not Opus** → escalate:
  spawn a fresh `proof-builder` on **Opus**, with the brief, the branch as it now stands
  and the failing output. Do not pause to ask. Tell the developer in one line, and record
  it for the PR's Notes: *"Escalated from Sonnet to Opus after two failed fix attempts on
  `lint`."*
- **Still failing on Opus** after two more attempts → the skill's *If it goes wrong* path.

Keep the builder's `notes` for the PR's Notes, and its `discovered` items for the
discovered-work step.

## 5. Checkpoint and resume

The checkpoint comment carries one extra line:

```markdown
**Builder:** sonnet          ← or opus, haiku, here; "sonnet → opus (escalated)" after an escalation
```

On a resume, read it and use the same builder without asking again. The builder from the
earlier session is gone, so spawn a fresh one with the checkpoint's *Done* and *Next*.
After an escalation, resume on Opus.

## 6. In the PR

Under **Notes**, say which model built it, and any escalation: *"Built by Sonnet."* or
*"Built by Sonnet; escalated to Opus after two failed fix attempts on `lint`."* Built
here: *"Built in the main session."*
