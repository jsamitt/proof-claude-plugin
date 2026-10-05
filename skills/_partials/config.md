# Project Config — read this first, every time

Proof carries **no project facts**. Commands, deploy steps, board stage names and
risk areas all come from the project, never from skill text. This is the rule that
keeps the harness reusable: if you ever find yourself about to hardcode a command,
a URL, a framework or a product fact into a skill, it belongs in the config instead.

## Load it

```bash
CFG=".claude/harness.json"
[ -f "$CFG" ] || { echo "No .claude/harness.json — run /proof-init first."; exit 1; }
```

Read the file and keep these in mind for the rest of the run:

| Key | Use |
|---|---|
| `project.name` / `project.summary` | Who this is for; tone of issues and specs |
| `project.docs` | Read these before speccing or building (e.g. `CLAUDE.md`) |
| `commands.*` | Never invent a test/build command — use these. `null` = not available |
| `verify.steps` | Which commands must pass before work is called done |
| `verify.manual` | Checks only the human can do; surface them, never claim them |
| `board.*` | Board title, field name, and the label for each stage |
| `labels.*` | Label names for ready / in-progress / discovered / blocked, the priority labels p1 / p2 / p3 / investigate, and needs_design (a design is awaited; `needs-design` if unset) |
| `voice.audience` | Who reads the output. Unset = the default product-manager reader in `_partials/voice.md` |
| `review.lenses` | Which reviewers run |
| `review.risk_focus` | The project's actual risk areas — the risk reviewer's brief |
| `goals` | What the project is trying to achieve now. Value ratings name the goal they serve. Empty = rate on merits, never invent goals |
| `ship.changelog` / `ship.store_notes` | The changelog file, and whether to draft app-store release notes. See `_partials/changelog.md` |
| `design.*` | Token module, reference URL (a Claude Design System link enables designing on a canvas in `/proof-spec`), platform and house rules. Unset = no design system; say so rather than inventing one |
| `ship.*` | Preflight checklist, ordered deploy steps, files holding the version |
| `learnings.file` | Where durable decisions are rolled up |
| `protected_paths` | Never edit these |
| `branch.base` / `branch.prefix` | Branch naming |

## Missing config

If `.claude/harness.json` is absent, **stop and tell the user to run `/proof-init`.**
Do not guess commands, invent board stages, or half-run the skill. A wrong test
command that silently passes is worse than no harness at all.

## Missing values

A `null` command or empty array means *the project does not have this*. Skip that
step and say so plainly in your output. Never substitute a command you guessed from
the file tree — if `commands.test` is null, there is no test step, full stop.
If you believe the project *should* have one, raise it as discovered work.
