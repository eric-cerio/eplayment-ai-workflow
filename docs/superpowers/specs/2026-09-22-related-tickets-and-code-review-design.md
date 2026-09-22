# Related-ticket intake and a code-review stage — design

**Status:** approved design, not yet built
**Date:** 2026-09-22
**Amends:** `2026-09-20-android-copilot-workflow-design.md` — section 8.1 (intake), 8.8 (commit and
push pre-flight) and 8.11 (the chains). Everything else there stands.

## 1. What this adds

Two changes to the Android workflow plugin:

1. **`android-plan` reads Jira.** Stage 01 fetches the Android ticket and its comments, finds the
   related `[BE]` and `[UI]` tickets, stops when one has not passed development, and carries their
   details and comments into the plan. Today the developer types the ticket fields by hand and
   nothing looks at the tickets the Android work depends on.
2. **A code-review stage, `android-review` (stage 07b).** It reviews the edited files for
   correctness, the repository's architecture and conventions, the Android squad standards and
   general practice, and **hard-blocks the push** on real defects. Today stage 05 checks format,
   lint and debris only; nothing checks quality before the push.

## 2. Why

- An Android ticket usually depends on a backend API (`[BE]`) and a UI/UX design (`[UI]`).
  Starting before the API is on the QA environment, or before the design has settled, produces
  work that is redone. The decisions that change an API or a design land in **comments**, which the
  typed intake never sees.
- Generated code reaches the push having passed lint, tests and a security gate, none of which ask
  whether it is correct, follows the repository's layering, or matches the backend contract.

## 3. Decisions

| Topic | Decision |
|---|---|
| Where Jira intake lives | Inside `android-plan`, replacing its step 1. No separate intake skill |
| Jira access | The Atlassian MCP server, each developer's own OAuth sign-in. Read-only |
| Finding related tickets | Issue links on the Android ticket, plus siblings under its parent |
| BE vs UI | The summary prefix: `[BE]` or `[UI]`. `[UI]` is the UI/UX design ticket |
| Passed development | `QA TESTING` or any status after it |
| A related ticket has not passed, or is dead | Stop. The developer may continue with a written waiver |
| No related ticket | Bugfix: one line, continue. Feature: ask once whether it is Android-only |
| Parent is an Epic | Show what was found and how; the developer drops unrelated keys in one answer |
| Applies to | `/ticket` and `/bugfix` alike |
| Code review | New skill `android-review`, stage 07b: after tests, before the security gate |
| Review blocking | Hard block with no override: must-fix findings stop the chain until the code changes |

## 4. Platform facts this design depends on

Check 7, run 2026-09-22 against Copilot CLI 1.0.87 — evidence in
`docs/checks/2026-09-22-plugin-mcp-check.md`:

- A plugin declaring the Agent Plugins v1 `$schema` reads its MCP servers **only from `mcp.json`
  at the plugin root**. `.mcp.json`, `com.github.copilot/mcp.json` and an `extensions` entry are
  ignored.
- A plugin MCP server is declared in **every** session once the plugin is installed — it is not
  inert outside Android repositories the way the hooks are.
- Android Studio's bundled runtime (1.0.56) predates this rule. Plugin MCP servers in the IDE are
  unproven, like plugin skills (check 1).

## 5. Jira access and configuration

### The server

The plugin ships `mcp.json` at its root declaring Atlassian's remote MCP server by URL
(`https://mcp.atlassian.com/v1/mcp`) with no credentials. Each developer signs in once with their
own Atlassian account when Copilot asks. Nothing secret enters this repository or any Android
repository. The endpoint is confirmed by the first real sign-in during manual acceptance; check 7
proved only that the declaration is read.

Skills must not depend on the server's name: a developer may already have an Atlassian server
configured by hand. They use whichever connected server offers the Jira tools.

**The Jira site** is the one whose host matches `jira_base` (default
`https://eplayment.atlassian.net/browse/`). No accessible site matches → stop and say which sites
the sign-in can see; never guess, and never fall back to the only site available.

**Read-only.** The skill fetches issues and runs JQL searches. It never transitions, comments on,
assigns, links or edits a Jira issue. The skill states this as a rule, because the same server
offers write tools.

### The `jira:` block

Optional, in `.ai/project/android-workflow.yml`. The defaults are the Eplayment Jira workflow, so a
repository sets it only to differ:

```yaml
jira:
  be_prefix: "[BE]"
  ui_prefix: "[UI]"
  passed_statuses:
    - QA TESTING
    - QA TESTED WITH FINDINGS
    - FOR STAGING DEPLOYMENT
    - STAGING TESTING
    - STAGING TESTED WITH FINDINGS
    - FOR PROD RELEASE
    - BLOCKED FOR PROD RELEASE
    - FOR PROD TESTING
    - IN PROD AND WORKING AS EXPECTED
    - FOR PUBLISHING
    - PUBLISHED
  findings_statuses: [QA TESTED WITH FINDINGS, STAGING TESTED WITH FINDINGS]
  dead_statuses: [DROPPED, INVALID]
```

- A status counts as **passed** only if `passed_statuses` lists it. Everything else is **not
  passed**: `TO DO`, `DEVELOPMENT`, `FOR QAT DEPLOYMENT`, `BLOCKED`, `CARRYOVER`, and any status
  added to the workflow later. An unknown status fails closed and is shown by name.
- `dead_statuses` are not passed and are flagged separately: a dropped backend ticket usually means
  the Android ticket needs rethinking, not waiting.
- Statuses and prefixes match case-insensitively. A prefix matches at the start of the summary,
  after leading whitespace.

### When Jira cannot be read

The MCP server is missing, signed out, or cannot reach the site → **stop** and print the setup
steps. The developer may continue by giving a written reason; the run then falls back to the
manual three-field intake of the 2026-09-20 design, and records `related.result: jira-waived` with
the reason. The check is never skipped silently.

## 6. Intake in `android-plan`

Replaces step 1. The probes, gate 1, and recording `plan_approved` only after the go are unchanged.

1. **Resolve the key**: argument → branch name → ask. Validate `<LETTERS>-<DIGITS>`.
2. **Check Jira access** (section 5).
3. **Read the Android ticket**: summary, issue type, status, description, parent, issue links, and
   all comments.
   - `name` — the summary without a leading bracketed tag (`[Android] Cancel reason` →
     `Cancel reason`).
   - Feature: **acceptance criteria**. Bugfix: **observed vs expected**. Both come from the
     description and the comments. Where a comment changes what the description says, the latest
     comment wins, and the plan says which comment changed what.
   - A field Jira does not supply → ask for that field only, one at a time, as before. Still
     missing → stop.
4. **Find the related tickets.**
   - Every issue link on the Android ticket, in both directions, of any link type.
   - Every child of the Android ticket's parent (`parent = <PARENT> AND key != <KEY>`).
   - Keep those whose summary starts with `be_prefix` or `ui_prefix`; the rest (`[iOS]`, `[QA]`,
     untagged) are not related for this purpose. Remove duplicates, keeping "link" as the source
     when a ticket is found both ways.
   - **Parent is an Epic** and at least one ticket came from it as a sibling → show the list, each
     with its role, status and how it was found, and let the developer drop unrelated keys in one
     answer. Record the drops. Under a Story or Task parent, siblings are kept without asking.
5. **Gate on status.** Read each related ticket's status, description and comments.
   - **All passed** → continue. A ticket in `findings_statuses` continues too, and the plan lists
     its open findings (from its comments) as known issues.
   - **Any not passed or dead** → **stop** with a table of key, role, status and a one-word verdict
     (`passed`, `not passed`, `dead`). The developer may continue by giving a written reason per
     blocking ticket, recorded verbatim. Without one, the run ends; rerunning
     `/android-plan <KEY>` reads the statuses again.
   - **None found**, bugfix → print "no BE or UI tickets found" and continue. Feature → ask once,
     "No BE or UI ticket found. Is this an Android-only change? (Y/N)". Y records
     `related.result: android-only`; N stops, so the link can be added in Jira.
6. **Extract what the plan needs.**
   - **BE**: the API contract — endpoint, method, request and response fields, error codes, auth
     requirements; the environment its status implies (QA, staging, production); open findings;
     and contract changes made in comments.
   - **UI**: Figma links, the screens and states covered, copy, and design changes made in
     comments. A Figma link from a `[UI]` ticket answers the optional UI-reference question, which
     is then not asked.
   - **No personal data leaves Jira.** Names, emails, phone numbers, account numbers and customer
     data in a description or comment are never copied into the ticket file or the plan. Comments
     are attributed by role and date ("BE comment, 2026-09-18"). If any was seen, say so once.
7. **Write the ticket file** — the fields, the `related:` block and the two new sections —
   immediately, before the probes. Probe 1 (code to reuse) now also compares the BE contract with
   the repository's existing API models, so a changed field is caught in the plan.
8. **Gate 1** as before. The plan repeats every related-ticket waiver.

**Resume.** `plan_approved` present → the chain resumes at the next stage and Jira is not read
again. Absent → a rerun reads Jira again; a blocked ticket that has since moved on clears the stop
without anyone editing the ticket file.

## 7. Ticket file changes

Two new blocks in the YAML header:

```yaml
related:
  result: ready          # ready | waived | android-only | none | jira-waived
  checked: 2026-09-22T19:10+08:00
  tickets:
    - {key: TA-2001, role: BE, status: QA TESTING, found: link}
    - {key: TA-2002, role: UI, status: DEVELOPMENT, found: sibling}
  dropped: [TA-1999]
  waivers:
    - {ticket: TA-2002, reason: "Design signed off in the review call; ticket not moved yet"}
review:
  result: pass           # pass | fail
  diff: 3f2a91c          # the same fingerprint as security.diff
```

`result: none` is a bugfix with no related tickets. For `jira-waived`, `waivers` holds one entry
with `ticket` set to the Android key and the reason.

Two new body sections, after `## Acceptance criteria`: `## From BE tickets` and
`## From UI tickets`, holding what step 6 extracted.

Writers: `android-plan` writes `related` and the two sections; `android-review` writes `review`.

## 8. `android-review` — stage 07b

### Where it runs

`/android-ship` becomes: lint (05) → release notes (06) → tests (07) → **review (07b)** → security
gate (08) → commit and push (09) → distribution note (10). It runs after the tests so that the
tests written in stage 07 are reviewed too, and before the security gate so that a review fix is
covered by the security pass. Run on its own, `/android-review` reviews the current changes.

### What it reviews

The same change set as the security gate — the diff against the merge base with `base_branch`, plus
staged and untracked files — limited to Kotlin, Java, XML resources and Gradle files. The
release-notes file and the `versionName` change made by stage 06 belong to that stage and are not
reviewed.

It reviews the changed hunks, reading each whole file for context. An issue outside the diff may be
mentioned for information; it never blocks.

### The sources, in order of authority

Every finding is labelled with its source.

1. **The repository**: `.ai/project/architecture.md` and `conventions.md`. Binding.
2. **The ticket**: the approved plan, the acceptance criteria, and the BE contract in
   `## From BE tickets`.
3. **The Android squad standards**, from the R&D Handbook MCP server, resolved as
   `.ai/department/rnd-squad-standards.md` describes: `lookup_person` for the current identity
   (`git config user.email`), the `/standards/android/` index, then only the pages this change
   touches, plus the cross-cutting `/standards/engineering/`. Each finding quotes the page path and
   its status. As of this design every standard is **draft**, so these findings are suggestions and
   say so. Server not connected → report "squad standards not checked" and continue.
4. **General Kotlin, Android and Compose practice**, labelled "general practice, not a company
   standard".

### Must-fix and suggestions

A **must-fix** finding blocks the push. Each one carries `file:line` and a **concrete failure
scenario** — the input or state, and what goes wrong. A finding without a scenario is a
suggestion, whatever its topic. Must-fix covers:

- behaviour that contradicts the approved plan or the acceptance criteria;
- API models or calls that do not match the BE contract;
- a network call with no error or empty state handled;
- `!!` on a value from the network, a bundle or an intent;
- crash and ANR risks: I/O on the main thread, a `Context` or `Activity` held by a ViewModel or a
  singleton, `GlobalScope`, a flow collected without lifecycle awareness;
- a break in the layering `architecture.md` or `conventions.md` requires, or a feature left
  unwired (DI binding or route missing);
- a stage 07 test that asserts nothing, or one weakened to pass.

**Suggestions** never block: draft standards, general practice, naming, readability, duplication,
and Compose structure (state hoisting, previews) unless it causes a correctness bug. Security
issues belong to stage 08: mention one if seen, and leave the verdict to the gate.

### The fix loop

There is **no override** for a must-fix finding: the code changes, or the push does not happen.
Neither waiver nor dismissal exists at this stage.

1. Present all findings at once, must-fix first, grouped by file.
2. Offer to fix the must-fix findings. On a yes, edit; otherwise the developer fixes by hand.
3. Run `android-lint` on the changed files and `android-test` on the affected scope. A failure
   stops the chain, as anywhere else.
4. Review the files the fix touched again. Repeat until nothing is must-fix.
5. Record `review.result: pass` and the diff fingerprint. Apply suggestions only when the developer
   picks them, then run step 3 again.

A developer who believes a finding is wrong reruns the review with the context that shows it —
the finding stands or falls on its failure scenario.

## 9. Changes to existing skills

| Skill | Change |
|---|---|
| `android-plan` | Step 1 becomes section 6. `reference.md` gains the intake rules and the extraction rules |
| `android-ship` | The 07b row. A must-fix stop ends the chain like a failing test |
| `android-commit-push` | Pre-flight, in order: protected branch → a `review` pass matching the fingerprint, else run `android-review` → a `security` pass matching it, else run the gate → nothing staged. Gate 3 also quotes the related-ticket waivers |
| `ticket`, `bugfix` | Descriptions list the review stage. Chain logic unchanged |
| `android-onboard` | Documents the optional `jira:` block, and reports whether the Atlassian and R&D Handbook servers are connected, without blocking |

`shared/config.md` gains the `jira:` block and its defaults; `shared/ticket-file.md` gains
section 7. `plugin.json` moves to `0.2.0`. The README gains the one-time Atlassian sign-in, and the
skills table gains `/android-review`.

The review is not a fourth human gate: it asks no approval, it stops the way a failing test does.

## 10. Policy and accepted risks

These are for the author to take to R&D. This design does not settle them.

- **Tier.** The workflow now calls tools that read a system of record with a person's credentials.
  `.ai/company/ai-usage-policy.md` puts that close to the Agent tier ("where something could be two
  tiers, the higher applies"), which carries hosting, credential and ownership requirements a
  per-developer plugin does not meet. R&D holds Technical Approval; raise it together with the
  registry entry already tracked as an accepted risk.
- **Personal data in tickets.** Bug tickets and their comments can hold customer personal data.
  Reading them sends that data to Copilot, which the "never enter into any AI tool" list forbids.
  The skill copies none of it onward, but cannot avoid reading it. Needs an R&D and DPO answer
  before rollout.
- **An AI finding alone can stop a push.** The hard block has no human override, which sits
  uneasily with "AI never owns a risk decision". The mitigation is the narrow must-fix definition:
  no concrete failure scenario, no block.
- **The Atlassian server is declared for every session**, not only in Android repositories
  (section 4). Accepted: an unused, signed-out server costs nothing but a line in `/mcp`.

## 11. Testing

| Level | What |
|---|---|
| `tests/lint-skills.sh` | The new skill passes; no repository-specific strings in any skill |
| `tests/run.sh` | The 21 hook cases still pass; the hooks do not change |
| Manual, CLI | On a PIXEL clone with a local bare remote, as in the 2026-09-20 design's section 11 |

Manual cases:

- A BE ticket in `DEVELOPMENT` → stop with the table; a waiver is recorded and shown at gates 1
  and 3; after the ticket moves to `QA TESTING`, a rerun continues without the waiver.
- A BE ticket in `QA TESTED WITH FINDINGS` → continues, and the findings are in the plan.
- An Epic parent → the drop list appears; dropped keys are recorded.
- A bugfix with no related ticket → one line. A feature with none → the Y/N question; N stops.
- Signed out of the Atlassian server → setup steps; with a waiver, the manual intake and
  `related.result: jira-waived`.
- The ticket file holds no names, emails or account numbers from comments.
- `/android-review` on a planted `!!` on a network field, and on a ViewModel calling the API
  directly → blocked; after the fix, lint and tests rerun and the review passes.
- A file edited after the review, then `/android-commit-push` → the review runs again before the
  security check.
- `/android-ship` runs 05 → 06 → 07 → 07b → 08 → 09 → 10.

## 12. Out of scope

Writing to Jira in any form; checking related tickets again at push time (the waiver is repeated
instead); iOS or web tickets; shipping the R&D Handbook server in `mcp.json`; renumbering the
existing stages.
