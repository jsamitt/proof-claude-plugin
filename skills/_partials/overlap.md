# Overlap check — look before anything new is created

A new issue that duplicates, quietly replaces or contradicts one already on the board is
cheap to catch at the door and expensive to untangle later: two issues get worked in
parallel, one gets built against criteria the other undoes, or an idea rejected in June
comes back in September with nobody remembering why it was rejected.

`/proof-plan --cleanup` finds these after the fact, across the whole backlog. This check
stops them **on the way in**, for one idea, while the context to decide is still in the
conversation.

Two strengths:

- **Full** — `/proof-spec`. Every relationship below, resolved in the session.
- **Light** — `/proof-fix` before it files a bug, and discovered work before it files
  anything. Duplicates only.

## What to search

1. **Open issues** — all of them, on the board or not.
2. **Open Discussions** in the Ideas category. If they cannot be read, skip them and say
   so in the one-line result.
3. **Issues closed in the last 90 days** — mostly to catch an idea that was turned down.
4. **The decisions file** (`learnings.file`) — for contradictions only.

Start cheap: titles and labels of every open issue in one call, plus a search on the
idea's own terms and on the screens or files it touches. Read the body only of issues
that look like candidates.

**The bar for a candidate:** someone who knows the product would say *"wait, isn't that
#12?"* — the same user problem, or the same behaviour changed in ways that interact. A
shared word is not overlap. Show at most five. If more than five genuinely qualify, the
idea is probably several ideas; say so, because that is the split question in `/proof-spec`.

## Relationships

| Relationship | What it means |
|---|---|
| **Duplicate / overlaps** | The same problem, in whole or part |
| **Supersedes** | Once this exists, the other issue is no longer needed |
| **Contradicts an issue** | Both cannot be built as written; their criteria pull opposite ways |
| **Contradicts a decision** | It undoes something the decisions file says was settled |
| **Belongs under a parent** | An existing parent issue's goal already covers it |
| **Previously turned down** | A matching issue was closed as not planned in the last 90 days |

## Presenting

**Nothing found:** one line and move on — no question.

> Checked 23 open issues, 4 Discussions and the decisions file — nothing overlaps.

**Something found:** one message, per `_partials/voice.md` — a row per match, each with a
recommendation, then one question.

```
Before we spec this, it touches three things already on record:

| | Existing | Relationship | Recommend |
|---|---|---|---|
| a | #12 Freeze count per week (Ready to Dev) | Overlaps — both change when freezes reset | Fold #12 into this spec and close it as a duplicate |
| b | #19 Unlimited freezes for Pro (Backlog) | Contradicts — #19 removes the weekly limit this relies on | Decide now: keep the limit and update #19, or drop it here |
| c | Decision: "A freeze covers one missed day, never two" | Contradicts — this would let one freeze cover a whole weekend | Keep the decision; change the criterion |

Which way on each? ("a, b: update #19, c" — or tell me what you would do differently)
```

## Resolving

| Relationship | Options (recommend one) |
|---|---|
| Duplicate / overlaps | Spec the existing issue instead · fold this idea into it · narrow this one to the part that does not overlap and link the two |
| Supersedes | Close the other as superseded once this exists · fold its useful parts into this spec first |
| Contradicts an issue | Change this spec · update the other issue's criteria · land this as a Discussion with the conflict as its open question |
| Contradicts a decision | Keep the decision and change the spec · supersede the decision (see below) |
| Belongs under a parent | Create it as a sub-issue of that parent |
| Previously turned down | Say why it was turned down, then ask what has changed. Nothing changed → recommend stopping here |

Rules that hold whatever is chosen:

- **Record now, apply at creation.** Changes to other issues are applied in the same
  step that creates the new issue or Discussion — never earlier. If the spec is
  abandoned halfway, nothing else has been touched. The one exception is *spec the
  existing issue instead*: switch to speccing that issue straight away, which changes
  nothing either.
- **In-flight work is never closed or rewritten.** If the other issue is In Dev or In
  Review, or has an open pull request, stop and ask: finish that first, stop it, or
  reshape this spec around it.
- **A Discussion cannot supersede an issue.** It is a parked concept, not a commitment.
  If the new idea lands as a Discussion, link the related issues and leave them open.
- **Explain every change on the other issue.** A comment saying what changed, why, and
  a link to the new issue — the same rule `/proof-plan` follows when closing. A closed
  issue with no explanation is a dead end for whoever finds it next.
- **Close with the right reason,** then take the issue off the board per
  `_partials/board.md`: *duplicate* for a duplicate, *not planned* for superseded.
- **Record the links on the new issue**, in its Notes: `Overlaps #9 — narrowed to …`,
  `Supersedes #12`, `Changes the decision "…"`.
- **Superseding a decision** goes through the superseding rule in
  `_partials/learnings.md` — proposed with the spec's learnings, confirmed like any
  promotion, never edited in silently.

## Light mode

Duplicates only, against open issues and issues closed in the last 90 days.

- **`/proof-fix`, before filing a bug:** *"This looks like #31 — use that one?"* If yes,
  work that issue and add the new details to it as a comment. A match that is **closed**
  as fixed means the bug may have come back — say so, because a regression changes
  where to look for the cause. Recommend reopening it, or a new issue that links it.
- **Discovered work, before presenting:** an item that matches an open issue gets the
  recommendation **Already tracked as #n** instead of File. If the new finding adds
  something #n does not say, offer to add it there as a comment.
