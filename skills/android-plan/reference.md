# Intake and planning — rules

Recovered from `.github/pixel-workflows/context-awareness.md`, with that repository's folder layout
and pattern rule moved to where they belong: each repository's `.ai/project/architecture.md` and
`conventions.md`.

## Intake

Three required fields, asked one at a time, and only for what the invocation did not already give:

| Field | Feature | Bugfix |
|---|---|---|
| **name** | short human title, reused verbatim in the commit message | the same |
| **key** | validated against `<LETTERS>-<DIGITS>`, e.g. `TA-1234` | the same |
| **the third** | acceptance criteria | observed vs expected |

A required field still missing after asking → **stop**. Half a ticket is not a plan, and the run
that starts on one produces work nobody asked for.

Then ask **once**, and never block on it:

- Feature: a **UI reference** — a Figma link or a screenshot path.
- Bugfix: **repro steps** or the affected screen.

"skip", "none" or silence is a complete answer. Derive the UI from the acceptance criteria instead,
and say in the plan that you did.

## The three probes

### 1. Code to reuse

Search for what already exists for this ticket: use cases, repository methods, design-system
components, API endpoints, domain models. The repository's `conventions.md` names where those live
— read it rather than guessing at folder names.

List the candidates in the plan, each with its path. **This is the probe that pays**: it is what
stops a second use case being written beside the one that already does the job.

### 2. The pattern already in that area

Look at the screen or package the ticket touches and report what it actually uses, with the file
you concluded it from. The repository's `architecture.md` is the authority on which pattern applies
to new code and on whether a legacy screen should be migrated or extended in place — follow it, and
if it does not say, present the choice rather than deciding silently.

A bugfix skips this probe: a fix follows the pattern of the code it touches, in place. You are not
scaffolding layers.

### 3. Git and ticket state

Report, without acting on any of it yet:

- the current branch, and whether a branch for this key already exists;
- a dirty working tree, listing what is uncommitted;
- recent commits touching the same area;
- whether the ticket's Jira URL is already in the release-notes file.

Resume rather than clobber: an existing branch is reused at stage 03, a dirty tree is the
developer's to resolve, and a release-notes line already present is not added twice.

## The plan

**Feature** — reuse list (with paths); the pattern to follow, with its evidence; the new files to
create; anything from probe 3 that needs a decision.

**Bugfix** — the suspected cause and how you reached it; the file or files to change; the smallest
fix that works; the same probe-3 warnings.

Say plainly what already exists and should be reused rather than rewritten. A plan that lists only
new files has usually skipped probe 1.

## Gate 1

Ask for approval of the plan, and for a feature, of the pattern choice. **Wait for an explicit
go.**

Record the ticket fields and the plan in the ticket file as soon as you have them — a run that
stops here still leaves everything behind. Record `plan_approved` **only after the go**, so
`/android-develop` cannot mistake a presented plan for an approved one.

Write no code in this stage, not even a stub.
