---
name: proof-design
description: Use when setting up or checking a project's design system — not part of every issue. Establishes a design system where a project has none, wire an existing one into the harness so the other skills obey it, or report drift between the tokens and the code — detects which of the three applies rather than being told
---

# Design

Makes a project's design system **real**: extracted if it does not exist, wired so the
harness can see it, and checked against the code that is supposed to use it.

```
/proof-design            # detect the state and act
/proof-design --drift    # skip straight to the drift report
```

Read `_partials/config.md` and `_partials/voice.md` first.

## The three states — detect, do not ask

Never ask the user which mode applies. Work it out, say which you found and why, then
proceed. Getting this wrong in the other direction is expensive: running an extraction
on a project that already has tokens writes a second, competing set, and two token files
is worse than none.

| State | How to tell | What to do |
|---|---|---|
| **None** | No token module; style values sit inline across the code | Extract → wire → report coverage |
| **Unwired** | Tokens exist; `design.tokens` is null or does not resolve | Wire → report coverage |
| **Wired** | `design.tokens` resolves and the app imports it | Report drift |

A project can be partly wired — tokens exist, the config points at them, but half the
code still hardcodes values. That is the **wired** state with poor coverage, not the
unwired one. Report the number; do not re-extract.

## 1. Establish (state: none)

### Inventory first, decide second

Sweep the code for every style value actually in use, with counts and locations:
colors, font families and weights, font sizes, spacing, radii, and anything else the
platform styles with. Count **occurrences**, not just distinct values — a colour used
40 times and one used once need different treatment, and the counts are what turn this
from opinion into arithmetic.

### Cluster the near-duplicates

This is the part that earns the skill. Values that differ imperceptibly are almost never
deliberate — they accumulate. Group them and propose one survivor per cluster, with the
most-used value as the default choice.

Be honest about the distinction between **a cluster and a distinction**: two greys three
points apart are a cluster; a warning amber and a brand gold that look similar may be
carrying different meanings. When you cannot tell from the code, say so and ask, rather
than collapsing a meaning the user cares about.

### Name by role, never by appearance

`--amber-500` tells you nothing about when to use it; `warning` does. A token named for
its colour has to be renamed the moment the colour changes, which defeats the point.
Where one value serves several roles, that is usually a sign it should be several tokens
sharing a value today.

### Present before writing — always

Show the proposed set: each token, its value, what it replaces, and the occurrence count
it covers. Show the clusters and which value won. Show anything you could not classify —
the leftovers are informative, and quietly dropping them hides the mess rather than
fixing it.

**Write nothing until the user approves.** Then write the token module in the form the
platform actually consumes (see below), and say plainly that no code has been migrated
yet — writing the file changes nothing on screen.

## 2. Wire (states: none, unwired)

A design system the harness cannot find is invisible: mockups stay generic, builds stay
unaware, and the design reviewer has nothing to cite. Wiring is what turns a file into a
constraint.

Set the `design` block in `.claude/harness.json`:

| Key | Meaning |
|---|---|
| `tokens` | Path to the token module the app imports |
| `reference` | URL of the browsable design system, if one exists. A **Claude Design System** link is the most useful kind: `/proof-spec` can then design small changes on a Claude Design canvas with the project's real tokens and components |
| `platform` | What consumes the tokens — decides the file's form and the rules that apply |
| `rules` | House rules in plain prose, one per line — the things that break silently here |

Then **verify, do not assume**:

- Every path in the block resolves. A pointer to a moved file is worse than no pointer:
  it fails silently and every skill downstream proceeds as if it read something.
- The token module is actually **imported by application code**, not merely present. A
  token file nobody imports is decoration.
- The `reference` URL, if set, is reachable.

Report each check. A wiring step that reports success without verifying is the failure
this section exists to prevent.

**A Claude Design System for the project.** If the user designs in Claude Design, or wants
`/proof-spec` to design small changes itself, offer to put the tokens (and, where they can
be previewed on the web, the components) into a Claude Design System, and set
`reference` to it. Claude Code's `/design-sync` skill does this where it is available; the
user starts it. Keep the token module in the repo as the source of truth — the design
system is a copy that designs are made from, and it goes stale if it is edited on its own.

## 3. Report coverage and drift (every state)

The number that matters is not how many tokens exist. It is **how much of the code uses
them**:

```
Tokens defined:        14
Raw values in code:    34 distinct, 80 occurrences
Covered by a token:    12 occurrences  (15%)
Unmigrated:            68 occurrences across 11 files
```

Adopting a design system is not finished when the file exists — it is finished when the
code uses it, and that gap is where most attempts quietly die. Report the real figure
even when it is embarrassing, and never describe a freshly written token file as done.

For a wired project, also report **drift**: values in the code that no token covers.
Drift is how a design system becomes a lie — the file says twelve colours, the app ships
thirty. Group drift by file so it can be cleared a screen at a time, and list the worst
offenders first.

Offer migration as a **separate, explicit step** the user chooses — never fold it into
this run. Migrating swaps values across many files and belongs in its own reviewable
change, ideally as a regular issue through `/proof-spec`.

## Platform shapes

The token file must be in the form the platform consumes, or it is a document rather
than a system. Read `design.platform`; if it is not set, infer it from the project and
record what you inferred.

- **Web / CSS** — custom properties on `:root`. Components read `var(--token)`.
- **React Native / Expo** — a **JavaScript or TypeScript module** exporting plain
  objects. CSS custom properties do not exist here, so a `.css` file is a reference
  document at best; `StyleSheet` needs values it can import.
- **Tailwind** — the theme block in the Tailwind config; everything else derives.
- **Native (Swift/Kotlin)** — the platform's own resource or constant files.

If a project has a design reference in one form (a published design system, a CSS file)
and ships in another, say so plainly: those values are **hand-copied**, and hand copies
drift. Name which one is authoritative and make the other derive from it.

## Rules

`design.rules` holds what breaks silently in this project — the things no general
ruleset knows. Write each as a concrete condition and consequence, not a principle:

- *"Wrap hardcoded pixel values in the scaling helper so layouts survive small phones and tablets"*
- *"Never put emoji inside a `<Text>` styled with a custom font — the glyph silently
  fails to render"*

These are what the design reviewer cites. A rule too vague to cite is not a rule.

## Hand back

The state you found, what changed, the coverage figure, and the honest next step — which
is usually migration, and usually its own issue.
