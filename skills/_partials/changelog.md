# Changelog and release notes

Used by `/proof-work` and `/proof-fix` (one entry per change) and `/proof-ship` (turning
those entries into a release). Read `ship.changelog` and `ship.store_notes` from the
config. If `ship.changelog` is null, the project keeps no changelog — skip all of this.

## Why entries are written with each change, not at release time

Two reasons. The base branch is protected, so release time is the wrong moment to be
writing files — everything has to arrive through a pull request anyway. And an entry
written while the change is fresh says *why*; one reconstructed from commit messages a
week later says *what*, which the diff already says.

## The Unreleased section

Every change that is worth telling someone about adds a line to an `## [Unreleased]`
section at the top of the changelog, **in the same pull request as the change**. Create
the section if it is missing. Group lines under the usual headings, in this order, using
only the ones that apply:

```markdown
## [Unreleased]

### Added
### Changed
### Fixed
### Removed
### Security
```

## What earns a line

A change a user would notice, a fix to something that was broken for them, anything
touching money, privacy or data, and anything a future you would need to know when
reading the history. Internal refactors, test-only changes and tooling do not earn a
line unless they change behaviour.

## How to write one

Follow the project's existing entries — match their tone, length and level of detail.
Where there is no house style yet, per `_partials/voice.md`:

- Lead with what changed **for the person using the product**
- Then the reason or the old symptom, in a clause: *"Previously the paywall stayed open
  after a successful purchase, which read as the purchase failing."*
- Name technical specifics only where a future reader needs them to find the change
- One entry per change; no issue-number soup

## Release notes for an app store

If `ship.store_notes` is true, `/proof-ship` also drafts the store's "What's New" text
from the released entries. It is a different audience and a different job:

- Written for the people who use the app — for a children's app, the parents
- Short: a few lines, most important first, no more than about 4,000 characters
- No internal names, file names, error codes or jargon
- Fixes described by the experience, not the cause: *"Subscribing now takes you
  straight back to your game"*, not *"auto-close paywall on purchase event"*
- Omit anything the user would not notice

The store text is presented for the user to paste into the store's console. It is not
committed unless the project keeps release notes in a file.
