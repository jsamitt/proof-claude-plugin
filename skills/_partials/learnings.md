# Learnings — the running record

The point of this harness is not the board. It is that six months from now you can
ask "why is it built this way?" and get an answer. Process comments ("picked up",
"PR opened") are not learnings and do not belong here.

## What counts

A learning is something **you did not know before the work started** and that would
change how you or Claude approach the next piece of work. Four kinds:

- **Decision** — a choice made, the reason, and what was rejected
- **Gotcha** — a non-obvious behaviour of the platform, a library, or the data
- **Correction** — something believed at spec time that turned out to be wrong
- **Surprise** — something that only showed up once it was running or shipped

**Not a learning:** restating the acceptance criteria, describing what the diff does,
narrating that a step happened, or anything readable straight off the code.

If a run produced nothing that meets that bar, **say "no learnings this run"** and
post nothing. An honest empty is worth more than filler — filler is what makes people
stop reading the log.

## When to capture

| Point | Typically captures |
|---|---|
| Spec approved | The decision and the alternatives rejected, with the reason |
| During build | Gotchas and corrections — the things that cost you an hour |
| After review | Findings worth remembering beyond this fix |
| After ship | Surprises: what behaved differently in the real app or in production |

## Format — post as an issue comment

Keep the heading exactly as shown; it is what makes these findable later via GitHub
search (`repo:<owner>/<repo> "Learnings —" <term>`).

```markdown
### 📓 Learnings — {Spec|Build|Review|Ship}

**Decision:** {what was chosen}
**Why:** {the reason, not the restatement}
**Rejected:** {the alternative and why it lost}

**Gotcha:** {the non-obvious behaviour, concrete enough to act on}
```

Include only the fields that apply. One comment per capture point; do not batch four
stages into one wall of text at the end.

## Promotion to the decisions file

Issue comments are cheap — a weak one costs a scroll. The decisions file is not: it is
read at the start of every spec and every build, so a weak entry costs attention every
time, forever. **The gate below is what keeps it readable.**

### The durability gate — all four, or it stays on the issue

Apply these to the candidate *as written*, not to the idea behind it. State the answers
out loud when proposing a promotion; a promotion proposed without them is not a
proposal, it is an assumption.

1. **Would it change a future decision?**
   If knowing it would not change what you do next time, it is trivia. *"We used a
   Map here"* — no. *"Keying by habit id, because a single blob loses every habit's
   history when one entry corrupts"* — yes.

2. **Is it still true once this issue ships?**
   Anything about the state of in-flight work is not durable. *"The freeze counter is not
   wired up yet"* expires the moment it is.

3. **Could someone read it off the code in under a minute?**
   If yes, the code is already the record — and a duplicate does not just waste space,
   it **drifts**, and a drifted entry is worse than none because it is believed.
   Promote the *reason*, never the mechanism.

4. **Is it specific enough to act on — a named condition and a named consequence?**
   *"Be careful with async storage"* fails. *"Writes over ~2KB fail silently in Expo Go
   but succeed in a dev build"* passes. If you cannot name what triggers it and what
   happens, you have a feeling, not a learning.

A candidate failing any one of these **stays on the issue**. It is not lost — it is
searchable there — it just does not earn a permanent seat. Say which question it failed
and move on; do not rewrite a weak candidate until it squeaks through, which is how the
bar quietly erodes.

### Superseding

When a new decision overrides one already in the file, **mark the old entry superseded
in the same commit** — never leave both standing:

```markdown
> **Superseded {YYYY-MM-DD}** by [{new title}](#anchor) — {one line on what changed}
```

Two entries giving contradictory answers is the failure that makes a decisions file
untrustworthy, and an untrustworthy record is worse than no record: it gets believed
once, burns you, and then gets ignored entirely.

### Doing it

When a candidate passes all four:

1. Propose it — quote the entry, say why it is durable, and **wait for confirmation.**
   Never write to the decisions file unprompted.
2. On approval, append to `learnings.file` from the config, newest first, under a
   dated heading that links back to the issue:

```markdown
## {YYYY-MM-DD} — {short title}  ([#{issue}]({url}))

{Decision / Why / Rejected / Gotcha, as applicable}
```

3. Commit it with the work: `docs: record decision — {short title} (refs #{issue})`

Two or three promotions a month is healthy. If you are promoting most candidates, the
bar has slipped — the file stops being readable and starts being an archive.

**Watch the size.** Past roughly 40 entries a decisions file stops being something
anyone reads start to finish, which is the only way it does its job. When it gets
there, prune before you add: entries about code that no longer exists, entries
superseded twice over, entries that would fail question 3 today because the code caught
up with them. Pruning is proposed and confirmed like any other write.

## Reading it back

Before speccing or building anything, skim `learnings.file` for entries touching the
same area, and say which ones you are applying. A record nobody reads is just a cost.

## When a lesson repeats

If a new learning says something the decisions file already says, **do not file it
again.** Post it on the issue as a one-line comment instead:

```markdown
### 🔁 Repeat of: {decisions entry title}
{one line on how it came up again}
```

The fixed heading is what lets `/proof-retro` count repeats later without re-reading
everything. A repeat is not a new lesson; it is evidence that the record was not read
before the work started. Tagging it is where learning stops — deciding what to change
about *how you work* because of it is the retro's job.
