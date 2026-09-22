# Intake and planning — rules

Recovered from `.github/pixel-workflows/context-awareness.md`, with that repository's folder layout
and pattern rule moved to where they belong: each repository's `.ai/project/architecture.md` and
`conventions.md`. The Jira intake is new in 0.2.0.

## Jira intake

### 1. The key

The argument, else the first `<LETTERS>-<DIGITS>` in the branch name, else ask. Validate it
against `<LETTERS>-<DIGITS>`, e.g. `TA-1234`.

### 2. Reaching Jira

Use whichever connected MCP server offers the Jira tools — do not depend on its name. As of
2026-09 the Atlassian server's tools are `getAccessibleAtlassianResources` (sites and their
`cloudId`), `getJiraIssue` and `searchJiraIssuesUsingJql`; if the names have changed, use the
equivalent read tools.

- **The site** is the one whose URL host equals the host of `jira_base`. None matches → stop and
  name the sites the sign-in can see. Never fall back to the only site available.
- **Read-only.** The same server offers tools that edit, transition, comment on and link issues.
  Never call one, for any reason — not even when asked mid-run to "just move the ticket". Say that
  is outside this workflow.

Server missing, signed out, or the site unreadable → stop and print:

```
Jira is not reachable, so the related BE and UI tickets cannot be checked.
Fix: run /mcp in Copilot, sign in to the Atlassian server with your own account, then rerun.
To continue without Jira, give a reason in words; it is recorded and shown again at the push.
```

A reason given → record `related.result: jira-waived` and
`waivers: [{ticket: <KEY>, reason: <verbatim>}]`, then run the **manual intake** below. No reason →
stop. Never skip the check silently, and never invent the reason.

### 3. The Android ticket

Fetch `summary`, `issuetype`, `status`, `description`, `parent`, `issuelinks` and `comment`. If the
response says there are more comments than it returned, fetch the rest.

| Field | From |
|---|---|
| **name** | the summary without one leading bracketed tag: `[Android] Cancel reason` → `Cancel reason`. Reused verbatim in the commit message |
| **acceptance criteria** (feature) / **observed vs expected** (fix) | the description, then the comments oldest to newest. Where a comment changes what the description says, the later one wins, and the plan names it: "comment, 2026-09-18: the reason is now optional" |

A field Jira does not supply → ask for that field only, one question at a time. Still missing →
**stop**. Half a ticket is not a plan, and the run that starts on one produces work nobody asked
for.

### 4. The related tickets

- **Links**: every entry in `issuelinks`, inward and outward, of any link type.
- **Siblings**: when the ticket has a parent, `parent = <PARENT> AND key != <KEY>`, every page.

Keep a ticket when its summary, after leading whitespace, starts with `jira.be_prefix` (role `BE`)
or `jira.ui_prefix` (role `UI`), ignoring case. Everything else — `[iOS]`, `[QA]`, untagged — is not
related for this check. A ticket found both ways is kept once, as `found: link`.

**Epic parent.** The parent's issue type is `Epic` and at least one kept ticket came from it as a
sibling → show the list and ask once:

```
Found for TA-1234 (parent epic TA-1900) — drop any that are not part of this ticket:
  TA-2001  BE  QA TESTING    link
  TA-2002  UI  DEVELOPMENT   sibling
  TA-1999  BE  TO DO         sibling
Keys to drop, or "none":
```

Record the dropped keys in `related.dropped`. Under a Story or Task parent, keep siblings without
asking.

### 5. The status gate

| Verdict | When the status is… |
|---|---|
| **passed** | in `jira.passed_statuses` |
| **passed, with findings** | also in `jira.findings_statuses` |
| **dead** | in `jira.dead_statuses` |
| **not passed** | anything else, including `BLOCKED`, `CARRYOVER`, and a status never seen before |

- **All passed** → `related.result: ready`; continue.
- **Any not passed or dead** → stop and show:

  ```
  Not ready to start TA-1234:
    TA-2001  BE  QA TESTING    passed
    TA-2002  UI  DEVELOPMENT   not passed
    TA-2003  BE  DROPPED       dead — the Android ticket may need rethinking, not waiting
  Rerun /android-plan TA-1234 once they reach QA TESTING or later,
  or give a reason for each blocking ticket to continue now.
  ```

  A reason for **every** blocking ticket → record each verbatim in `related.waivers`, set
  `result: waived`, continue. Reasons for some but not all → still stopped. Never invent a reason
  and never continue on your own initiative.
- **None kept**, bugfix → print `no BE or UI tickets found`, set `result: none`, continue.
  Feature → ask once: `No BE or UI ticket found. Is this an Android-only change? (Y/N)`.
  Y → `result: android-only`, continue. N → stop: "Link the BE and UI tickets in Jira, then rerun
  /android-plan <KEY>."

Record `related.checked` (now, with offset) and every kept ticket's `key`, `role`, `status` and
`found`.

### 6. What to take from the BE and UI tickets

Read the description and every comment of each kept ticket, waived ones included.

`## From BE tickets`, per ticket:

- **The API contract**: endpoints, method, request fields, response fields and their types, error
  codes, the auth requirement. None written down → say so: "TA-2001 has no API contract; confirm
  with the BE owner". That is a warning in the plan, not a stop.
- **Where it can be called now**, from its status: `QA TESTING`, `QA TESTED WITH FINDINGS` and
  `FOR STAGING DEPLOYMENT` → QA; `STAGING …`, `FOR PROD RELEASE` and `BLOCKED FOR PROD RELEASE` →
  staging; `FOR PROD TESTING` onwards → production.
- **Open findings**, when its status is in `jira.findings_statuses`.
- **Contract changes made in comments**, dated, the later winning.

`## From UI tickets`, per ticket: the Figma links (exact URLs), the screens and states covered
(empty, loading, error), the copy, and design changes made in comments. A Figma link here **is**
the UI reference; do not ask for one.

### 7. Personal data stays in Jira

Never copy into the ticket file or the plan: names, emails, phone numbers, account or card numbers,
addresses, or any customer data from a description, a comment or an attachment name. Attribute by
role and date — "BE comment, 2026-09-18" — never by author. Customer data seen in a ticket → say
once "this ticket contains customer data; none of it was copied", and describe the behaviour, not
the data.

### Manual intake (only after `jira-waived`)

Three required fields, asked one at a time, only for what the invocation did not already give:

| Field | Feature | Bugfix |
|---|---|---|
| **name** | short human title, reused verbatim in the commit message | the same |
| **key** | validated against `<LETTERS>-<DIGITS>`, e.g. `TA-1234` | the same |
| **the third** | acceptance criteria | observed vs expected |

A required field still missing after asking → **stop**.

### The optional question

Then ask **once**, and never block on it — unless a `[UI]` ticket already supplied a Figma link:

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

When `## From BE tickets` has a contract, find the repository's existing API interface and models
for the same endpoint and list every field that is new, renamed, or of a different type or
nullability. Those go in the plan; they are where the Android change and the backend disagree.

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

**Both** — the related-ticket table with each verdict; every waiver, verbatim; the open findings of
any ticket in a findings status; and the contract differences probe 1 found.

Say plainly what already exists and should be reused rather than rewritten. A plan that lists only
new files has usually skipped probe 1.

## Gate 1

Ask for approval of the plan, and for a feature, of the pattern choice. **Wait for an explicit
go.**

Record the ticket fields and the plan in the ticket file as soon as you have them — a run that
stops here still leaves everything behind. Record `plan_approved` **only after the go**, so
`/android-develop` cannot mistake a presented plan for an approved one.

Write no code in this stage, not even a stub.
