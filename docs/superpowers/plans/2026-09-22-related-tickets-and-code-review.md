# Related-Ticket Intake and Code Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `android-plan` reads the Android ticket and its related `[BE]`/`[UI]` tickets from Jira and stops unless they have passed development; a new `android-review` stage (07b) hard-blocks the push on must-fix defects.

**Architecture:** The plugin ships an `mcp.json` declaring Atlassian's remote MCP server (URL only; each developer signs in). `android-plan`'s step 1 becomes a read-only Jira intake that records a `related:` block and two new sections in the ticket file. A new stage skill `android-review` runs between tests and the security gate and records a `review:` block keyed to the same diff fingerprint as the security gate; `android-commit-push` requires both before gate 3.

**Tech Stack:** Markdown skills (Copilot Agent Skills), bash (lint, fixtures), GitHub Copilot CLI 1.0.87, Atlassian remote MCP server, R&D Handbook MCP server.

**Spec:** `docs/superpowers/specs/2026-09-22-related-tickets-and-code-review-design.md` (amends `docs/superpowers/specs/2026-09-20-android-copilot-workflow-design.md`). Check 7 evidence: `docs/checks/2026-09-22-plugin-mcp-check.md`.

## Global Constraints

- `PLUGIN=/Users/ericcerio/Projects/Eplayment/ai-workflow` in every command below.
- **No skill may contain** a repository name (`PIXEL`, `eplayment-*`), a `/Users/` path, or a Gradle task name outside a worked example. `tests/lint-skills.sh` enforces it.
- **Nothing this workflow needs may live in `.ai/company/` or `.ai/department/`.**
- **Skills find shared files by the plugin root** (the nearest ancestor holding `plugin.json`), never by a `../` path. Every SKILL.md carries the same "Finding these files" block the existing skills carry, verbatim.
- **Jira is read-only.** No skill transitions, comments on, assigns, links, creates or edits a Jira issue — and no test step does either through Copilot. Fixture tickets are made by a person, by hand.
- **Personal data never leaves Jira**: no names, emails, phone numbers, account or card numbers, addresses or customer data in the ticket file or the plan. Comments are attributed by role and date.
- **MCP declaration:** `mcp.json` at the plugin root (never `.mcp.json`), server `atlassian`, `"type": "http"`, `"url": "https://mcp.atlassian.com/v1/mcp"`, no `headers`, no credentials. Skills never depend on the server's name.
- **Status lists, verbatim:** passed = `QA TESTING, QA TESTED WITH FINDINGS, FOR STAGING DEPLOYMENT, STAGING TESTING, STAGING TESTED WITH FINDINGS, FOR PROD RELEASE, BLOCKED FOR PROD RELEASE, FOR PROD TESTING, IN PROD AND WORKING AS EXPECTED, FOR PUBLISHING, PUBLISHED`; findings = `QA TESTED WITH FINDINGS, STAGING TESTED WITH FINDINGS`; dead = `DROPPED, INVALID`. Anything else is not passed. Matching ignores case.
- **Prefixes:** `[BE]` backend, `[UI]` UI/UX design, matched at the start of the summary after leading whitespace, ignoring case.
- **Review:** stage number `07b` (do not renumber other stages). A must-fix finding needs `file:line` plus a concrete failure scenario; without one it is a suggestion. **No override**: no waiver, no dismissal.
- **Fingerprint:** exactly the command in `shared/ticket-file.md` → "The diff fingerprint". `review.diff` and `security.diff` use the same one.
- **Commits in this repo:** conventional (`feat:`, `test:`, `docs:`, `fix:`), ending with `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`. Work on the branch `feat/related-tickets-and-review`. **Never push, merge to `main`, or tag without the user's explicit go**: everyone auto-updates from `main`, and rollout waits on the R&D/DPO answers to spec §10.
- **Local runs:** `copilot --plugin-dir "$PLUGIN" --allow-all-tools --no-ask-user -p "<prompt>"`. `--plugin-dir` **replaces** the installed `android-workflow` 0.1.0 of the same name (verified in Task 1: `copilot --plugin-dir "$PLUGIN" skill list --json` gives one `android-plan`, at the working copy's path), so the installed copy needs no disabling — and cannot be disabled anyway, being a direct install. Each run costs AI credits; do not loop them.

## File Structure

| Path | Change | Responsibility |
|---|---|---|
| `mcp.json` | create | Declares the Atlassian server for every install |
| `tests/lint-skills.sh` | modify | + `mcp.json` rules, + backticked skill names must exist |
| `tests/fixtures/new-repo.sh` | modify | + `full-config` variant for skill runs |
| `tests/fixtures/review-repo.sh` | create | Scratch Kotlin repo with an approved ticket, `defects` or `clean`, optionally with recorded passes |
| `shared/config.md` | modify | The `jira:` block and its defaults |
| `shared/ticket-file.md` | modify | `related:` and `review:` blocks, two sections, writers |
| `skills/android-plan/{SKILL,reference}.md` | modify | Jira intake, status gate, extraction |
| `skills/android-release-notes/{SKILL,reference}.md` | modify | Safe to rerun under `patch-bump` |
| `skills/android-review/{SKILL,reference}.md` | create | Stage 07b |
| `skills/android-ship/SKILL.md` | modify | The 07b row |
| `skills/android-commit-push/{SKILL,reference}.md` | modify | Require a current review; quote related waivers |
| `skills/ticket/SKILL.md`, `skills/bugfix/SKILL.md` | modify | Descriptions name the review |
| `skills/android-onboard/{SKILL,reference}.md` | modify | Document `jira:`, report MCP connections |
| `README.md`, `plugin.json` | modify | Jira sign-in, skills table, `0.2.0` |
| `docs/superpowers/specs/2026-09-22-related-tickets-and-code-review-design.md` | modify | §9 gains the stage 06 row (Task 4) |
| `docs/checks/2026-09-22-acceptance-0.2.0.md` | create | Manual acceptance results |

---

### Task 1: Ship the Atlassian MCP declaration

**Files:**
- Create: `mcp.json`
- Modify: `tests/lint-skills.sh` (after the `for skill` loop, before the final `[ $fail -eq 0 ]` line), `README.md` (new `### Jira` section in "Install")

**Interfaces:**
- Produces: a server named `atlassian` in every session where the plugin is loaded; lint rules that keep `mcp.json` credential-free.

- [x] **Step 1: Confirm the working copy is what `--plugin-dir` loads**

`copilot plugin disable` refuses a direct install, so check instead that `--plugin-dir` wins:

```bash
copilot --plugin-dir "$PLUGIN" skill list --json | grep -o '"path": *"[^"]*android-plan"'
```
Expected: one path, inside `$PLUGIN`. (Without `--plugin-dir` it is the installed copy's path.)

- [ ] **Step 2: Add the lint rules**

Insert into `tests/lint-skills.sh`, after the `done` that closes the `for skill` loop:

```bash
# Plugin MCP servers (check 7): a v1-schema plugin reads only mcp.json at its root, and the
# declaration carries a URL, never a credential — each developer signs in.
[ -e "$root/mcp.json" ] || note "mcp.json: missing; android-plan needs the Atlassian server declared"
[ -e "$root/.mcp.json" ] && note ".mcp.json: ignored by v1-schema plugins; the file must be mcp.json"
if [ -e "$root/mcp.json" ]; then
  grep -q '"mcpServers"' "$root/mcp.json" || note "mcp.json: no mcpServers object"
  grep -qiE '"(headers|env|authorization|token|apikey|api_key|password|secret)"' "$root/mcp.json" \
    && note "mcp.json: declares headers or credentials; each developer signs in instead"
fi
```

- [ ] **Step 3: Run the lint to watch it fail**

Run: `"$PLUGIN/tests/lint-skills.sh"; echo "exit $?"`
Expected: `mcp.json: missing; android-plan needs the Atlassian server declared`, then `exit 1`.

- [ ] **Step 4: Write `mcp.json`**

```json
{
  "mcpServers": {
    "atlassian": {
      "type": "http",
      "url": "https://mcp.atlassian.com/v1/mcp"
    }
  }
}
```

- [ ] **Step 5: Run the lint to verify it passes, then prove the other two rules bite**

```bash
"$PLUGIN/tests/lint-skills.sh"
T="$(mktemp -d)" && cp -R "$PLUGIN/." "$T/" && cp "$T/mcp.json" "$T/.mcp.json" \
  && sed -i '' 's/"type": "http",/"type": "http", "headers": {"X": "y"},/' "$T/mcp.json" \
  && "$T/tests/lint-skills.sh"; rm -rf "$T"
```
Expected: first `skill lint: OK`; then exactly the `.mcp.json: ignored…` and `mcp.json: declares headers…` lines.

- [ ] **Step 6: Verify Copilot loads the declaration from this plugin**

```bash
S="$(mktemp -d)" && cd "$S" && copilot --plugin-dir "$PLUGIN" --log-dir "$S/logs" --log-level debug \
  --allow-all-tools --no-ask-user -p "Reply with exactly the word ok. Do not call any tools." >/dev/null
/usr/bin/grep -h 'discover_and_start_root' "$S"/logs/*.log | grep -o 'mcp.atlassian.com/v1/mcp' | head -1
```
Expected: `mcp.atlassian.com/v1/mcp`. An authentication failure for that server later in the log is expected and fine.

- [ ] **Step 7: Document the sign-in in `README.md`**

After the paragraph ending "…see [`shared/config.md`](shared/config.md)." in "Install", add:

```markdown
### Jira

`/android-plan` reads the ticket, and its related `[BE]` and `[UI]` tickets, from Jira through the
Atlassian MCP server this plugin declares in `mcp.json`. Sign in once with your own Atlassian
account when Copilot asks; `/mcp` shows whether it is connected. The plugin carries no token and
never writes to Jira.

The server is declared in every Copilot session once the plugin is installed, not only in Android
repositories. Signed out, it costs nothing but an unconnected line in `/mcp`.
```

- [ ] **Step 8: Commit**

```bash
cd "$PLUGIN" && git add mcp.json tests/lint-skills.sh README.md
git commit -m "feat: declare the Atlassian MCP server in mcp.json, linted credential-free

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Config and ticket-file contracts, and onboarding

**Files:**
- Modify: `shared/config.md`, `shared/ticket-file.md`, `skills/android-onboard/SKILL.md` (step 9), `skills/android-onboard/reference.md` ("The rest" table + new section)

**Interfaces:**
- Produces: config keys `jira.be_prefix`, `jira.ui_prefix`, `jira.passed_statuses`, `jira.findings_statuses`, `jira.dead_statuses`; ticket-file blocks `related:` {`result`: `ready|waived|android-only|none|jira-waived`, `checked`, `tickets[]` {`key`, `role`: `BE|UI`, `status`, `found`: `link|sibling`}, `dropped[]`, `waivers[]` {`ticket`, `reason`}} and `review:` {`result`: `pass|fail`, `diff`}; sections `## From BE tickets`, `## From UI tickets`.

- [ ] **Step 1: Add the `jira:` block to the example in `shared/config.md`**

In the fenced YAML under "## The file", after the `security:` block's last line, add:

```yaml

jira:                                   # optional; the defaults are the Eplayment Jira workflow
  be_prefix: "[BE]"                     # summary prefix of a backend ticket
  ui_prefix: "[UI]"                     # summary prefix of a UI/UX design ticket
  passed_statuses: [QA TESTING, QA TESTED WITH FINDINGS, FOR STAGING DEPLOYMENT, STAGING TESTING,
                    STAGING TESTED WITH FINDINGS, FOR PROD RELEASE, BLOCKED FOR PROD RELEASE,
                    FOR PROD TESTING, IN PROD AND WORKING AS EXPECTED, FOR PUBLISHING, PUBLISHED]
  findings_statuses: [QA TESTED WITH FINDINGS, STAGING TESTED WITH FINDINGS]
  dead_statuses: [DROPPED, INVALID]
```

- [ ] **Step 2: Add the defaults rows and the status rules to `shared/config.md`**

Append to the "## Defaults" table:

```markdown
| `jira.be_prefix` | `[BE]` |
| `jira.ui_prefix` | `[UI]` |
| `jira.passed_statuses` | the eleven statuses above, `QA TESTING` onwards |
| `jira.findings_statuses` | `[QA TESTED WITH FINDINGS, STAGING TESTED WITH FINDINGS]` |
| `jira.dead_statuses` | `[DROPPED, INVALID]` |
```

Then add, after the "## Defaults" section:

```markdown
## Jira statuses

- A related ticket has **passed development** only when `jira.passed_statuses` lists its status.
  Everything else is **not passed** — `TO DO`, `DEVELOPMENT`, `FOR QAT DEPLOYMENT`, `BLOCKED`,
  `CARRYOVER`, and any status added to the Jira workflow later. An unknown status fails closed.
- `jira.dead_statuses` are not passed and are flagged separately: a dropped backend ticket usually
  means the Android ticket needs rethinking, not waiting.
- Statuses and prefixes compare ignoring case. A prefix matches at the start of the summary, after
  leading whitespace.
- A repository writes the `jira:` block only when its Jira project differs. A list it gives
  **replaces** the default list; it is not merged with it.
```

- [ ] **Step 3: Extend the format in `shared/ticket-file.md`**

In the "## Format" YAML, insert after the `plan_approved:` line:

```yaml
related:
  result: waived              # ready | waived | android-only | none | jira-waived
  checked: 2026-09-21T10:02+08:00
  tickets:
    - {key: TA-2001, role: BE, status: QA TESTING, found: link}
    - {key: TA-2002, role: UI, status: DEVELOPMENT, found: sibling}
  dropped: [TA-1999]          # listed, then dropped by the developer as unrelated
  waivers:
    - {ticket: TA-2002, reason: "Design signed off in the review call; ticket not moved yet"}
review:
  result: pass                # pass | fail
  diff: 3f2a91c               # the same fingerprint as security.diff
```

and replace the body sections under the closing `---` with:

```markdown
## Acceptance criteria

(For a bugfix: observed vs expected.)

## From BE tickets

(API contract, environment, open findings, contract changes from comments.)

## From UI tickets

(Figma links, screens and states, copy, design changes from comments.)

## Approved plan

(What stage 02 presented and the developer approved.)
```

- [ ] **Step 4: Document the `related` block, the writers and the review fingerprint in `shared/ticket-file.md`**

Add a section after "## Format":

```markdown
## The `related` block

| `result` | Meaning |
|---|---|
| `ready` | every related ticket has passed development |
| `waived` | at least one has not, and the developer gave a reason for each such ticket |
| `android-only` | a feature with no related ticket, confirmed Android-only by the developer |
| `none` | a bugfix with no related ticket |
| `jira-waived` | Jira could not be read; `waivers` holds one entry whose `ticket` is this ticket's own key |

Waiver reasons are the developer's words, verbatim. They are repeated at gate 1 and at gate 3.
```

In "## Who writes what", replace the `android-plan` row and add one row:

```markdown
| `android-plan` | `key`, `name`, `type`, `architecture`, the `related:` block, the four sections, and `plan_approved` **only after the go** |
| `android-review` | the whole `review:` block |
```

At the end of "## The diff fingerprint", add:

```markdown
`review.diff` records the same fingerprint for the code review. `android-commit-push` checks the
review first, then security: a change after either expires it, and a review fix always expires the
security pass.
```

- [ ] **Step 5: Onboarding — document `jira:` and report the connections**

In `skills/android-onboard/reference.md`, add a row to "## The rest":

```markdown
| `jira` | **Leave it out.** The defaults are the Eplayment Jira workflow. Write the block only when the developer says this repository's Jira project uses other statuses or prefixes |
```

and add a section before "## Drafting the architecture docs":

```markdown
## Connections to report

Check, and never block on either:

- **Atlassian** — a connected MCP server that offers the Jira tools and can see the site in
  `jira_base`. `android-plan` needs it.
- **R&D Handbook** — a connected server offering `lookup_person` and `get_page`.
  `android-review` uses it for the Android squad standards.

Report each as connected or not, with the fix: "run `/mcp` and sign in".
```

In `skills/android-onboard/SKILL.md` step 9, change "as three short lists:" to "as four short lists:" and add a fourth bullet:

```markdown
   - **connections**: whether the Atlassian and R&D Handbook servers are connected, per
     `reference.md`.
```

- [x] **Step 5b: The fingerprint hashes untracked contents (added during execution, user-approved)**

Found while editing the contract: `git ls-files --others | sort` hashes untracked file **names**,
so editing a new file after a pass left the fingerprint — and the pass — unchanged. A regression
check in `tests/run.sh` takes the command from `shared/ticket-file.md` and requires the
fingerprint to change when an untracked file's contents do (it failed first: `21 passed,
1 failed`). The contract now pipes each untracked path through `git hash-object`. From here on
`tests/run.sh` reports `22 passed`.

- [ ] **Step 6: Verify**

```bash
cd "$PLUGIN" && ./tests/lint-skills.sh && ./tests/run.sh | tail -1
grep -c 'QA TESTING' shared/config.md
grep -nE '^\| `android-(plan|review)` \|' shared/ticket-file.md
grep -n 'four short lists' skills/android-onboard/SKILL.md
```
Expected: `skill lint: OK`; `2` (the example's first line and the defaults row); both writer rows;
one line.

- [ ] **Step 7: Commit**

```bash
git add shared/config.md shared/ticket-file.md skills/android-onboard
git commit -m "docs: jira config block, related and review ticket-file blocks, onboarding checks

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `android-plan` reads Jira

**Files:**
- Modify: `skills/android-plan/SKILL.md` (whole file), `skills/android-plan/reference.md` ("## Intake" replaced; probe 1 and "## The plan" extended), `tests/fixtures/new-repo.sh` (+ `full-config`), `README.md` (the `/android-plan` row)

**Interfaces:**
- Consumes: Task 2's config keys and ticket-file blocks; the `atlassian` server from Task 1.
- Produces: a ticket file with `related:` and the `## From BE tickets` / `## From UI tickets` sections, which `android-review` (Task 5) reads; the `full-config` fixture variant (Tasks 4 and 7).

- [ ] **Step 1: Add the `full-config` fixture variant**

In `tests/fixtures/new-repo.sh`, add `| full-config` to the variants comment on line 3, and add after the `narrowed-config` if/elif/fi block:

```bash
if [ "$variant" = "full-config" ]; then
  cat > .ai/project/android-workflow.yml <<'YML'
workflow_version: 0.2.0
app_tag: TEST
jira_base: https://eplayment.atlassian.net/browse/
base_branch: develop
protected_branches: [develop, main, master]
build:
  gradle_file: app/build.gradle
  lint_task: lintDebug
  test_task: testDebugUnitTest
release_notes:
  file: release_notes.txt
  mode: append
YML
  : > release_notes.txt
fi
```

and change the case arm `on-feature|with-post-edit-check|narrowed-config)` to `on-feature|with-post-edit-check|narrowed-config|full-config)`.

Run: `"$PLUGIN/tests/run.sh" | tail -1`
Expected: `22 passed, 0 failed`.

- [ ] **Step 2: Capture the "before" behaviour**

```bash
R="$("$PLUGIN/tests/fixtures/new-repo.sh" full-config)" && cd "$R"
copilot --plugin-dir "$PLUGIN" --disable-mcp-server atlassian --allow-all-tools --no-ask-user \
  -p "/android-plan TA-1234 feature" | tail -15
```
Expected (the failing case): it wants the ticket fields typed by hand and never mentions Jira.

- [ ] **Step 3: Rewrite `skills/android-plan/SKILL.md`**

```markdown
---
name: android-plan
description: Plan an Android feature or bugfix before any code is written - read the ticket and its related BE and UI tickets from Jira, stop if they have not passed development, find what to reuse, detect the architecture pattern and git state, then present the plan for approval. Use when the user wants to plan a ticket or a fix, check whether a ticket is ready to start, investigate what a change would touch, or as stages 01-02 of the Android workflow.
---

# Plan — stages 01+02 (gate 1)

Read `shared/config.md` and `shared/ticket-file.md`, then `reference.md` here.

> **Finding these files:** they live in the **plugin root** — the nearest ancestor directory of
> this skill file that contains `plugin.json`. Locate that directory first, then read
> `<plugin-root>/shared/<file>.md`. They are not in the repository you are working in, and not
> under `skills/`. If you cannot find them, say so and stop rather than continuing without them.

Usage: `/android-plan <KEY> [feature|fix]`. No type given → ask which it is.

**Already approved?** `plan_approved` set in the ticket file → say so, name the next step, and
stop. Re-plan only if the developer asks, and then read Jira again.

1. **Jira intake**, as `reference.md` describes: resolve the key, reach Jira, read the ticket and
   its comments, find the related `[BE]` and `[UI]` tickets, and gate on their status.
   **Jira is read-only: never change anything in it.**
   - A related ticket not passed, or dead → **stop**, unless the developer gives a reason in words
     for every such ticket.
   - Jira unreadable → **stop**, unless the developer gives a reason in words; then run the manual
     intake in `reference.md`.
2. **Record** the fields, the `related:` block and the `## From BE tickets` / `## From UI tickets`
   sections in the ticket file as soon as you have them, before anything else. Then ask **once**
   for a UI reference (feature) or repro steps (fix) — unless a `[UI]` ticket already gave a Figma
   link. "skip" is a complete answer.
3. **Probes.** Run the three in `reference.md`: code to reuse (including the BE contract against the
   existing API models), the pattern in the touched area (features only), and git and ticket
   state. Report, do not act.
4. **Present the plan**, saying plainly what already exists and should be reused rather than
   rewritten. Show the related-ticket table, every waiver verbatim, and the open findings of any
   ticket in a findings status.
5. **Gate 1.** Ask for approval of the plan, and for a feature, of the pattern choice.
   **Wait for an explicit go.** Record `plan_approved` **only after the go**.
6. **Say what comes next**: `/android-branch`, or `/ticket <KEY>` to run the rest of the workflow.

Write no code here, not even a stub. That is `/android-develop`, and only after approval.
```

- [ ] **Step 4: Replace "## Intake" in `skills/android-plan/reference.md`**

Replace everything from `## Intake` up to (not including) `## The three probes` with:

````markdown
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
**stop**.

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
````

- [ ] **Step 5: Extend probe 1 and "## The plan" in the same file**

At the end of "### 1. Code to reuse", add:

```markdown
When `## From BE tickets` has a contract, find the repository's existing API interface and models
for the same endpoint and list every field that is new, renamed, or of a different type or
nullability. Those go in the plan; they are where the Android change and the backend disagree.
```

In "## The plan", add a paragraph after the **Bugfix** paragraph:

```markdown
**Both** — the related-ticket table with each verdict; every waiver, verbatim; the open findings of
any ticket in a findings status; and the contract differences probe 1 found.
```

- [ ] **Step 6: Run the lint**

Run: `"$PLUGIN/tests/lint-skills.sh"`
Expected: `skill lint: OK`.

- [ ] **Step 7: Verify the signed-out path**

```bash
R="$("$PLUGIN/tests/fixtures/new-repo.sh" full-config)" && cd "$R"
copilot --plugin-dir "$PLUGIN" --disable-mcp-server atlassian --allow-all-tools --no-ask-user \
  -p "/android-plan TA-1234 feature" | tail -15
f="$(git rev-parse --git-common-dir)/android-workflow/TA-1234.md"; [ -e "$f" ] && cat "$f"
git status --porcelain
```
Expected: the "Jira is not reachable" block with the `/mcp` fix; no `plan_approved` and no
`related.result` in any ticket file (it could not obtain a reason); `git status` empty.

- [ ] **Step 8: Developer smoke run against real Jira (needs the developer's sign-in)**

In an **interactive** session in a fresh `full-config` fixture, with a real feature key whose
`[BE]` ticket is in `QA TESTING` or later and which holds no customer data:

```bash
copilot --plugin-dir "$PLUGIN"
# then type: /android-plan <KEY> feature     — and answer "stop" at gate 1
```
Expected: the related-ticket table, a `related:` block with `result: ready`, a filled
`## From BE tickets`, no author names in the ticket file, and no `plan_approved`.

- [ ] **Step 9: Update the README row and commit**

In `README.md`, change the `/android-plan` row to:

```markdown
| `/android-plan <KEY> [feature\|fix]` | 01+02 | **gate 1** — the plan; stops first if a `[BE]` or `[UI]` ticket has not passed development |
```

```bash
cd "$PLUGIN" && git add skills/android-plan tests/fixtures/new-repo.sh README.md
git commit -m "feat: android-plan reads Jira and gates on related BE and UI tickets

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Stage 06 is safe to rerun

The review stops the chain on must-fix findings, and the way back in is to rerun `/android-ship` —
which reruns stage 06. Under `patch-bump` that bumps `versionName` a second time
(`3.4.28` → `3.4.29`). Release notes are already safe (`append` skips duplicates, `replace` rewrites
the branch's lines) and `branch-suffix` never stacks suffixes; only `patch-bump` needs the fix.

**Files:**
- Modify: `skills/android-release-notes/reference.md` ("### `rule: patch-bump`"), `skills/android-release-notes/SKILL.md` (step 3), `docs/superpowers/specs/2026-09-22-related-tickets-and-code-review-design.md` (§9 table)

**Interfaces:**
- Consumes: the `full-config` fixture variant (Task 3).
- Produces: stage 06 changes nothing on a second run, which Task 5's "rerun `/android-ship`" relies on.

- [ ] **Step 1: Watch it bump twice**

```bash
R="$("$PLUGIN/tests/fixtures/new-repo.sh" full-config)" && cd "$R"
for i in 1 2; do copilot --plugin-dir "$PLUGIN" --allow-all-tools --no-ask-user \
  -p "/android-release-notes TA-1234" >/dev/null; grep versionName app/build.gradle; done
```
Expected (the failing case): `3.4.28` after the first run, `3.4.29` after the second.

- [ ] **Step 2: Add the rule to `reference.md`**

Under "### `rule: patch-bump`", after "…stop and ask rather than guessing.", add:

````markdown
**Once per branch.** Compare with the base before bumping:

```bash
git show "$(git merge-base HEAD <base_branch>):<build.gradle_file>" | grep -m1 versionName
```

The working tree's `versionName` already differs from the base's → this branch has been bumped;
say "already bumped on this branch (3.4.27 → 3.4.28)" and change nothing. A chain that stops and
is run again must not bump twice.
````

- [ ] **Step 3: Point step 3 of `SKILL.md` at it**

Replace step 3 with:

```markdown
3. **Version**: apply `versioning.rule` to `versionName` in `build.gradle_file` — **once per
   branch**: already changed from the base → say so and leave it. **Never touch `versionCode`.**
```

- [ ] **Step 4: Verify the second run changes nothing**

Rerun Step 1's commands in a fresh fixture.
Expected: `3.4.28` both times, and the second run says it was already bumped.

- [ ] **Step 5: Record it in the spec and commit**

Add a row to the §9 table of the 2026-09-22 spec:

```markdown
| `android-release-notes` | `patch-bump` bumps once per branch, compared with the merge base, so rerunning `/android-ship` after a review stop does not bump twice |
```

```bash
cd "$PLUGIN" && ./tests/lint-skills.sh && git add skills/android-release-notes docs/superpowers/specs
git commit -m "fix: stage 06 bumps versionName once per branch, so the chain can rerun

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `android-review` — stage 07b

**Files:**
- Create: `skills/android-review/SKILL.md`, `skills/android-review/reference.md`, `tests/fixtures/review-repo.sh`
- Modify: `tests/lint-skills.sh` (inside the `for skill` loop), `skills/android-ship/SKILL.md`, `skills/ticket/SKILL.md`, `skills/bugfix/SKILL.md`, `README.md`

**Interfaces:**
- Consumes: `## From BE tickets`, `## Acceptance criteria`, `## Approved plan` (Task 3); the fingerprint command; the `android-lint` and `android-test` skills; stage 06 safe to rerun (Task 4).
- Produces: `review.result` (`pass`/`fail`) and `review.diff`, read by `android-commit-push` (Task 6); `tests/fixtures/review-repo.sh <defects|clean> [passed]`, which prints the repo path.

- [ ] **Step 1: Lint that every backticked skill name exists**

Inside the `for skill` loop of `tests/lint-skills.sh`, after the `../` check, add:

```bash
  # A skill named in backticks must exist, so a chain cannot call a stage that is not there.
  while read -r ref; do
    [ -n "$ref" ] || continue
    [ -d "$root/skills/${ref#/}" ] || note "$rel: names skill ${ref#/}, which does not exist"
  done < <(grep -oE '`/?android-[a-z-]+`' "$skill" | tr -d '`' | sort -u)
```

Run: `"$PLUGIN/tests/lint-skills.sh"`
Expected: `skill lint: OK` — every name used today exists.

- [ ] **Step 2: Add the 07b row to `android-ship`, and watch the lint fail**

In `skills/android-ship/SKILL.md`, add the row between 07 and 08:

```markdown
| 07b | `android-review` | **hard block** — must-fix findings stop the chain until the code changes |
```

change the description's stage list to "lint, release notes and version, tests, a code review, the
security gate, commit and push, then the distribution note", and replace the stop paragraph with:

```markdown
**Stop at the first stage that fails**, and say which one and why. A failing test, a must-fix
review finding or a blocked security gate ends the chain; it does not get skipped so the push can
proceed. Rerunning `/android-ship` after the fix is safe: stage 06 does not bump twice.
```

Run: `"$PLUGIN/tests/lint-skills.sh"; echo "exit $?"`
Expected: `skills/android-ship/SKILL.md: names skill android-review, which does not exist`, `exit 1`.

- [ ] **Step 3: Write the fixture `tests/fixtures/review-repo.sh`**

```bash
#!/usr/bin/env bash
# Scratch Kotlin repo on feature/TA-1234 with an approved ticket and an uncommitted change.
# Usage: review-repo.sh <defects|clean> [passed]
#   defects: the ViewModel calls the Api directly, uses !! on the body, and is not wired.
#   clean:   the ViewModel goes through the use case, maps failure to a state, and is wired.
#   passed:  also record review and security passes for the current changes.
set -eu
shape="${1:?defects or clean}"; passed="${2:-}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# The fingerprint command, taken from its contract so the fixture can never drift from it.
fp_cmd="$(awk '/^## The diff fingerprint/{s=1} s&&/^```bash/{c=1;next} c&&/^```/{exit} c' \
  "$root/shared/ticket-file.md" | sed 's/<base_branch>/develop/g')"
dir="$(mktemp -d)"; cd "$dir"
git init -q -b develop .
git config user.email t@example.com; git config user.name Test
pkg=app/src/main/java/com/example/cancel; di=app/src/main/java/com/example/di
mkdir -p "$pkg" "$di" .ai/project
cat > .ai/project/android-workflow.yml <<'YML'
workflow_version: 0.2.0
app_tag: TEST
base_branch: develop
build:
  gradle_file: app/build.gradle
  lint_task: lintDebug
  test_task: testDebugUnitTest
release_notes:
  file: release_notes.txt
YML
cat > .ai/project/architecture.md <<'MD'
# Architecture
- Layering: `ViewModel → UseCase → Repository → Api`. A ViewModel never calls an `*Api` interface.
- Repositories return `Result<T>`; ViewModels map a failure to an error state the UI can show.
- Wiring: every ViewModel gets a factory function in `app/src/main/java/com/example/di/AppModule.kt`.
MD
printf '# Conventions\n- User-facing strings live in `res/values/strings.xml`.\n' > .ai/project/conventions.md
printf 'android {\n  defaultConfig {\n    versionCode 60\n    versionName "3.4.27"\n  }\n}\n' > app/build.gradle
: > release_notes.txt
cat > "$pkg/CancelApi.kt" <<'KT'
package com.example.cancel

import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST

data class CancelRequest(val reasonCode: String)
data class CancelResponse(val status: String)

interface CancelApi {
    @POST("subscriptions/cancel")
    suspend fun cancel(@Body body: CancelRequest): Response<CancelResponse>
}
KT
cat > "$pkg/CancelRepository.kt" <<'KT'
package com.example.cancel

class CancelRepository(private val api: CancelApi) {
    suspend fun cancel(reasonCode: String): Result<CancelResponse> = runCatching {
        api.cancel(CancelRequest(reasonCode)).body() ?: error("empty body")
    }
}
KT
cat > "$pkg/CancelUseCase.kt" <<'KT'
package com.example.cancel

class CancelUseCase(private val repository: CancelRepository) {
    suspend operator fun invoke(reasonCode: String) = repository.cancel(reasonCode)
}
KT
cat > "$di/AppModule.kt" <<'KT'
package com.example.di

object AppModule
KT
git add -A && git commit -qm "initial"
git checkout -qb feature/TA-1234

if [ "$shape" = "defects" ]; then
cat > "$pkg/CancelReasonViewModel.kt" <<'KT'
package com.example.cancel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class CancelReasonViewModel(private val api: CancelApi) : ViewModel() {
    private val _status = MutableStateFlow("")
    val status: StateFlow<String> = _status

    fun submit(reasonCode: String) {
        viewModelScope.launch {
            val response = api.cancel(CancelRequest(reasonCode))
            _status.value = response.body()!!.status
        }
    }
}
KT
else
cat > "$pkg/CancelReasonViewModel.kt" <<'KT'
package com.example.cancel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class CancelReasonViewModel(private val cancel: CancelUseCase) : ViewModel() {
    private val _state = MutableStateFlow<CancelState>(CancelState.Idle)
    val state: StateFlow<CancelState> = _state

    fun submit(reasonCode: String) {
        viewModelScope.launch {
            _state.value = cancel(reasonCode).fold(
                onSuccess = { CancelState.Done(it.status) },
                onFailure = { CancelState.Error },
            )
        }
    }
}

sealed interface CancelState {
    data object Idle : CancelState
    data class Done(val status: String) : CancelState
    data object Error : CancelState
}
KT
cat > "$di/AppModule.kt" <<'KT'
package com.example.di

import com.example.cancel.CancelApi
import com.example.cancel.CancelReasonViewModel
import com.example.cancel.CancelRepository
import com.example.cancel.CancelUseCase

object AppModule {
    fun cancelReasonViewModel(api: CancelApi) =
        CancelReasonViewModel(CancelUseCase(CancelRepository(api)))
}
KT
fi

fp="$(bash -c "$fp_cmd")"
tdir="$(git rev-parse --git-common-dir)/android-workflow"; mkdir -p "$tdir"
{
  printf -- '---\nkey: TA-1234\nname: Cancel reason\ntype: feature\nbranch: feature/TA-1234\n'
  printf 'architecture: MVVM\nplan_approved: 2026-09-22T10:00+08:00\n'
  printf 'related:\n  result: waived\n  checked: 2026-09-22T09:50+08:00\n  tickets:\n'
  printf '    - {key: TA-2001, role: BE, status: QA TESTING, found: link}\n'
  printf '    - {key: TA-2002, role: UI, status: DEVELOPMENT, found: sibling}\n'
  printf '  waivers:\n    - {ticket: TA-2002, reason: "Design signed off in the review call; ticket not moved yet"}\n'
  if [ "$passed" = "passed" ]; then
    printf 'review:\n  result: pass\n  diff: %s\nsecurity:\n  result: pass\n  diff: %s\n' "$fp" "$fp"
  fi
  printf 'workflow_version: 0.2.0\n---\n\n## Acceptance criteria\n\n'
  printf -- '- Submitting a reason cancels the subscription and shows the returned status.\n'
  printf -- '- A failed cancel shows an error state.\n\n## From BE tickets\n\n'
  printf 'TA-2001: `POST subscriptions/cancel`, body `{reasonCode: String}`, returns `{status: String}`; 4xx on an unknown code. Callable on QA.\n\n'
  printf '## From UI tickets\n\nTA-2002: not yet designed (waived).\n\n## Approved plan\n\n'
  printf 'Add `CancelReasonViewModel` using `CancelUseCase`, exposing idle, done and error states; add its factory to `AppModule`.\n'
} > "$tdir/TA-1234.md"
printf '%s\n' "$dir"
```

```bash
chmod +x "$PLUGIN/tests/fixtures/review-repo.sh"
R="$("$PLUGIN/tests/fixtures/review-repo.sh" defects)" && git -C "$R" status --short \
  && head -12 "$(git -C "$R" rev-parse --git-common-dir)/android-workflow/TA-1234.md"
```
Expected: `?? app/src/main/java/com/example/cancel/CancelReasonViewModel.kt`, then the ticket header.

- [ ] **Step 4: Write `skills/android-review/SKILL.md`**

```markdown
---
name: android-review
description: Review the Android changes on this branch for correctness, the repository's architecture and conventions, the backend contract, the Android squad standards and general practice, and block the push on must-fix findings until the code changes. Use when the user asks for a code review, a quality or standards check of their changes, or before pushing, or as stage 07b of the Android workflow.
---

# Code review — stage 07b (hard block)

Read `shared/config.md` and `shared/ticket-file.md`, then `reference.md` here.

> **Finding these files:** they live in the **plugin root** — the nearest ancestor directory of
> this skill file that contains `plugin.json`. Locate that directory first, then read
> `<plugin-root>/shared/<file>.md`. They are not in the repository you are working in, and not
> under `skills/`. If you cannot find them, say so and stop rather than continuing without them.

1. **Resolve the ticket key**: argument → branch name → ask. "none" is an answer: review anyway,
   without the ticket's sources, and record nothing.
2. **Collect the change set** with the command in `reference.md`. Nothing → say so and stop.
3. **Load the sources** in `reference.md`'s order, and say which you could not load.
4. **Review** every changed hunk, reading the whole file for context, against `reference.md`.
   Label every finding with its source.
5. **Present all findings at once**, must-fix first, grouped by file, each with `file:line`; each
   must-fix also with its failure scenario and its fix.
6. **Must-fix present → the push is blocked, and there is no override** — no waiver, no dismissal.
   Offer to fix them. On a yes, fix exactly those; then run the `android-lint` skill and the
   `android-test` skill on the classes touched, and review the touched files again, until nothing
   is must-fix. On a no, stop with `review.result: fail`: "Fix them, then rerun `/android-ship`".
7. **Record** `review.result` and the diff fingerprint, computed exactly as `shared/ticket-file.md`
   defines it, after the last change.
8. **Suggestions** are applied only when the developer picks them; then step 6's lint, tests and
   re-review run again, and step 7 records the new fingerprint.

End with one line: `Review: clear for the security gate`, or `Review: blocked — <n> must-fix`.

Never fix a suggestion unasked, never downgrade a must-fix to get through, and never treat code
outside the change set as part of it.
```

- [ ] **Step 5: Write `skills/android-review/reference.md`**

````markdown
# Code review — rules

Stage 07b. It runs after the tests (07), so the tests written there are reviewed too, and before
the security gate (08), so a fix made here is inside the security pass.

## The change set

```bash
base="$(git merge-base HEAD <base_branch>)"
{ git diff --name-only "$base"; git diff --cached --name-only; \
  git ls-files --others --exclude-standard; } | sort -u | grep -E '\.(kt|kts|java|xml|gradle)$'
```

Review the changed hunks (`git diff "$base" -- <file>`; the whole file when it is untracked), and
read the whole file for context. Leave out the `versionName` line stage 06 changed in
`build.gradle_file`; the rest of a Gradle file's changes are reviewed.

An issue outside the changed hunks is "outside this change": mention it at most once, never as
must-fix.

## The sources, in order

| # | Source | Force | Label |
|---|---|---|---|
| 1 | `.ai/project/architecture.md`, `.ai/project/conventions.md` | binding | `repo: architecture.md` |
| 2 | the ticket file: `## Approved plan`, `## Acceptance criteria`, `## From BE tickets` | binding | `ticket: plan`, `ticket: BE contract` |
| 3 | the Android squad standards (R&D Handbook) | per page status | `standard: <path> (<status>)` |
| 4 | general Kotlin, Android and Compose practice | suggestion | `general practice, not a company standard` |

**The squad standards**, as `.ai/department/rnd-squad-standards.md` describes when the repository
has it: identity from `git config user.email`; `lookup_person` for the squads and their
`owns_paths`; `get_page` on the `/standards/android/` index, then only the pages this change needs
(Compose, networking, testing — whatever the hunks touch); and the `/standards/engineering/` pages
outside `api/` and `git-workflow/`. Quote each page's path and `status`:

- `active` → binding, like source 1;
- `draft` → a suggestion that says it is draft;
- `not-started` → nothing to apply.

`squads: []` or no identity → do not guess a squad: the files are Android, so use
`/standards/android/` and say that is the basis. Server not connected → report "squad standards
not checked" and continue.

A standard or a practice never makes something must-fix on its own; a failure scenario does.

## Must-fix

Each carries `file:line` and a **failure scenario**: the input or state, and what goes wrong. No
scenario → it is a suggestion, whatever its topic.

| Check | A must-fix looks like |
|---|---|
| Plan and acceptance criteria | a criterion not met: "AC 2 wants an error state; a failed cancel leaves the old status on screen" |
| BE contract | a field name, type or nullability that differs from `## From BE tickets`: `@SerializedName("reason_code")` where the contract says `reasonCode` |
| Error and empty states | a network call whose failure or empty result reaches no UI state |
| `!!` on outside data | `response.body()!!`, `intent.getStringExtra("id")!!`, `arguments!!` |
| Main thread | disk, network or database work with no background dispatcher on a path from the UI |
| Leaks | a `Context`, `Activity`, `View` or `Fragment` held by a ViewModel, a singleton or a companion object |
| Scope | `GlobalScope.launch`; `runBlocking` on the main thread |
| Lifecycle | a `Flow` collected in a Fragment or Activity outside `repeatOnLifecycle` / `flowWithLifecycle` |
| Layering | a break in the layering `architecture.md` requires: a ViewModel calling an `*Api`, a Composable calling a repository |
| Wiring | a new ViewModel, use case, repository or screen with no DI binding or factory, or no route, where `architecture.md` requires one |
| Tests | a stage 07 test that asserts nothing, asserts a constant, or whose expectation was edited to match wrong output |

## Suggestions

Never block: draft standards; general practice; naming; readability; duplication (a second helper
beside one that already does the job); Kotlin idiom; Compose structure — state hoisting, stable
parameters, `remember` keys, previews — unless it produces a wrong UI, which is must-fix with its
scenario.

## Not this stage's

Formatting and lint belong to stage 05: do not repeat them. Security — secrets, personal data in
logs, permissions, pinning, cleartext — belongs to stage 08: note "for the security gate" and move
on.

## Presenting

```
MUST-FIX  app/src/main/java/.../CancelReasonViewModel.kt:15   [repo: architecture.md]
  The ViewModel calls CancelApi directly; architecture.md requires ViewModel → UseCase → Repository → Api.
  Scenario: any submit bypasses CancelRepository's Result mapping, so a 4xx reaches no error state.
  Fix: inject CancelUseCase and map its Result to the UI state.

SUGGESTION  app/src/main/java/.../CancelReasonViewModel.kt:9   [general practice, not a company standard]
  Expose a sealed UI state instead of a bare String status, so the screen can render loading and error.
```

## The fix loop

- **No override exists** — not a waiver, not a dismissal, not "fix it after the push".
- Ask once: `Fix the must-fix findings now? (Y/N)`. Y → change exactly those. N → stop with
  `review.result: fail` and the line "Fix them, then rerun `/android-ship`".
- After a fix: the `android-lint` skill, then the `android-test` skill scoped to the classes
  touched. A failure stops the chain as anywhere else.
- Review the files the fix touched again, not the whole change set; a new must-fix there loops.
- A developer who thinks a finding is wrong reruns the review with the context that shows it. The
  finding stands or falls on its scenario: context showing the scenario cannot happen (the BE
  contract guarantees the field, say) makes it not must-fix.

## Recording

Write `review.result` — `pass` only with zero must-fix — and `review.diff`, the fingerprint from
`shared/ticket-file.md`, after the last change. Record `fail` with its fingerprint too, so
`android-commit-push` knows the review ran and did not clear.
````

- [ ] **Step 6: Run the lint to verify it passes**

Run: `"$PLUGIN/tests/lint-skills.sh"`
Expected: `skill lint: OK`.

- [ ] **Step 7: Verify it blocks on the defects fixture**

```bash
R="$("$PLUGIN/tests/fixtures/review-repo.sh" defects)" && cd "$R"
copilot --plugin-dir "$PLUGIN" --allow-all-tools --no-ask-user -p "/android-review TA-1234" | tail -25
grep -A2 '^review:' "$(git rev-parse --git-common-dir)/android-workflow/TA-1234.md"
git status --short
```
Expected: MUST-FIX findings for at least the layering (the `api.cancel` line), the `!!` on
`response.body()`, and the missing `AppModule` factory — an unhandled-error finding on the same
call is also correct; `Review: blocked — <n> must-fix` with n ≥ 3;
`review:` with `result: fail` and a fingerprint; the ViewModel still untracked and unchanged (with
no one to answer the Y/N, nothing is fixed).

> **Found in execution:** the first Step 7 run found the right three must-fix findings, then fixed
> them without a yes (it could not ask, and took that as permission) and recorded `pass` although
> Gradle never ran. `SKILL.md` step 6 and "The fix loop" now say that no answer is a no, and that a
> fix counts only when lint and tests actually ran. A must-fix labelled with its check's name
> rather than its source also led to the "label is always the source" rule. The rerun: 4 must-fix
> (the three planted plus the unmet error-state criterion), `result: fail`, nothing edited.

- [ ] **Step 8: Verify it clears the clean fixture**

```bash
R="$("$PLUGIN/tests/fixtures/review-repo.sh" clean)" && cd "$R"
copilot --plugin-dir "$PLUGIN" --allow-all-tools --no-ask-user -p "/android-review TA-1234" | tail -8
fp="$(bash -c "$(awk '/^## The diff fingerprint/{s=1} s&&/^```bash/{c=1;next} c&&/^```/{exit} c' \
  "$PLUGIN/shared/ticket-file.md" | sed 's/<base_branch>/develop/g')")"
grep -A2 '^review:' "$(git rev-parse --git-common-dir)/android-workflow/TA-1234.md"; echo "expected diff: $fp"
```
Expected: no MUST-FIX (suggestions allowed), `Review: clear for the security gate`,
`result: pass`, and `diff:` equal to the printed fingerprint.

- [ ] **Step 9: Name the review in the chains and the README, then commit**

`skills/ticket/SKILL.md` and `skills/bugfix/SKILL.md`: in the description, "lint, version, tests,
security gate" → "lint, version, tests, code review, security gate"; in step 4, "stages 05 to 10,
with gates 2 and 3 inside it" → "stages 05 to 10 with the 07b code review, and gates 2 and 3
inside it".

`README.md`: add after the `/android-test` row

```markdown
| `/android-review` | 07b | **hard block** — must-fix findings stop the push until the code changes |
```

and in "Developing", change the lint comment to
`# frontmatter, references, skill names, mcp.json, no repo-specific strings, no ../ paths`.

```bash
cd "$PLUGIN" && ./tests/lint-skills.sh && ./tests/run.sh | tail -1
git add skills/android-review skills/android-ship skills/ticket skills/bugfix \
  tests/lint-skills.sh tests/fixtures/review-repo.sh README.md
git commit -m "feat: android-review skill (stage 07b), a hard block on must-fix findings

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```
Expected before the commit: `skill lint: OK`, `22 passed, 0 failed`.

---

### Task 6: `android-commit-push` requires a current review

**Files:**
- Modify: `skills/android-commit-push/SKILL.md` (description, steps 2 and 4), `skills/android-commit-push/reference.md` ("## Pre-flight, in order", "## Gate 3 — what the developer sees")

**Interfaces:**
- Consumes: `review.{result,diff}` (Task 5), `security.{result,diff,waivers}`, `related.waivers` (Task 3); `tests/fixtures/review-repo.sh clean passed` (Task 5).

- [ ] **Step 1: Watch it ignore a stale review**

```bash
R="$("$PLUGIN/tests/fixtures/review-repo.sh" clean passed)" && cd "$R"
git init -q --bare "$R.remote.git" && git remote add origin "$R.remote.git"
printf '// touched after the review\n' >> app/src/main/java/com/example/cancel/CancelReasonViewModel.kt
copilot --plugin-dir "$PLUGIN" --allow-all-tools --no-ask-user -p "/android-commit-push TA-1234" | tail -20
```
Expected (the failing case): it reruns the security gate for the new fingerprint but never the
review. The local bare remote keeps gate 3 reachable without any real remote.

- [ ] **Step 2: Rewrite the pre-flight in `reference.md`**

Replace items 2 and 3 of "## Pre-flight, in order" with:

```markdown
2. **The code review has passed for these exact changes.** Recompute the diff fingerprint and
   compare it with `review.diff`. Missing, `fail`, or a different fingerprint → run the
   `android-review` skill now and continue only if it clears. The review comes first because a
   review fix changes the code, and so the fingerprint.
3. **The security gate has passed for these exact changes.** Recompute the fingerprint again and
   compare it with `security.diff`. Missing, `fail`, or a different fingerprint → run the
   `android-security-gate` skill now and continue only if it clears.
4. **Nothing is staged yet.** Whatever the run staged earlier, the developer approves the file list
   before anything is added.
```

- [ ] **Step 3: Quote the related waivers at gate 3**

In "## Gate 3 — what the developer sees", replace "Plus any security waivers, quoted, so they are
read one more time before they reach a reviewer." with:

````markdown
Plus every waiver, quoted, so it is read one more time before it reaches a reviewer:

```
waivers:  security  "new dependency com.foo:bar" — vendor SDK required by TA-1234, agreed with the security owner
          related   TA-2002 (UI, DEVELOPMENT) — "Design signed off in the review call; ticket not moved yet"
```

A `jira-waived` intake is shown the same way, with the ticket's own key.
````

- [ ] **Step 4: Update `SKILL.md`**

In the description, replace "Requires a passing security gate for the current changes." with
"Requires a passing code review and security gate for the current changes." Replace step 2 with:

```markdown
2. **Require a current review, then a current security pass.** Recompute the diff fingerprint.
   No matching `review: pass` → run the `android-review` skill now and continue only if it clears.
   Then no matching `security` `pass` or `waived` → run the `android-security-gate` skill now and
   continue only if it clears.
```

In step 4, change "and any waivers" to "and every waiver — security and related-ticket — quoted".

- [ ] **Step 5: Verify a fresh pass goes straight to gate 3, and a stale review runs first**

```bash
R="$("$PLUGIN/tests/fixtures/review-repo.sh" clean passed)" && cd "$R"
git init -q --bare "$R.remote.git" && git remote add origin "$R.remote.git"
copilot --plugin-dir "$PLUGIN" --allow-all-tools --no-ask-user -p "/android-commit-push TA-1234" | tail -20
git log --oneline | wc -l; git diff --cached --name-only | wc -l
```
Expected (fresh): neither the review nor the security gate reruns; gate 3 shows
`TA-1234: Cancel reason`, the files, `feature/TA-1234 → origin`, and the `related TA-2002` waiver
quoted; then it stops. `1` commit, `0` staged.

```bash
printf '// touched after the review\n' >> app/src/main/java/com/example/cancel/CancelReasonViewModel.kt
copilot --plugin-dir "$PLUGIN" --allow-all-tools --no-ask-user -p "/android-commit-push TA-1234" | tail -20
git log --oneline | wc -l; git diff --cached --name-only | wc -l
```
Expected (stale): a `Review:` line appears **before** any security-gate output; still `1` commit,
`0` staged.

> **Found in execution:** the Step 1 baseline ran security **then** review (the shared contract
> from Task 2 prompted the review; the skill's own order was wrong). The first stale run of Step 5
> ordered them correctly but then **pushed without a yes at gate 3** — "given non-interactive mode,
> I'll proceed" — to the scratch bare remote. Gate 3 (and, as the same failure mode, gates 1 and 2)
> now state that no answer is a no. Rerun: review → security → gate 3 shown → stopped; 1 commit,
> 0 staged, nothing on the remote.

- [ ] **Step 6: Commit**

```bash
cd "$PLUGIN" && ./tests/lint-skills.sh
git add skills/android-commit-push skills/android-plan/SKILL.md skills/android-security-gate/SKILL.md
git commit -m "feat: android-commit-push requires a current review and quotes related waivers

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Manual acceptance and 0.2.0 — the release waits for the user

**Files:**
- Create: `docs/checks/2026-09-22-acceptance-0.2.0.md`
- Modify: `plugin.json` (`"version": "0.2.0"`)

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Make the fixture tickets (a person, in Jira, by hand)**

In a sandbox Jira project on the `jira_base` site, with **synthetic content only** — no customer
data, since spec §10 is unanswered. Record the keys in the acceptance doc.

| Ticket | Shape |
|---|---|
| F1 | `[Android]` feature under a Story; linked `[BE]` in `QA TESTING` with an API contract; sibling `[UI]` in `QA TESTED WITH FINDINGS` with a Figma link and one findings comment; one BE comment containing a made-up name, email and phone number |
| F2 | feature with a linked `[BE]` in `DEVELOPMENT` |
| F3 | feature under an **Epic**, with a linked `[BE]` and an unrelated `[BE]` sibling in `TO DO` |
| F4 | feature with a linked `[BE]` in `DROPPED` |
| F5 | feature with no `[BE]`/`[UI]` link or sibling |
| B1 | bug with no `[BE]`/`[UI]` link or sibling |

- [ ] **Step 2: Run the scenarios in an interactive CLI session**

In a fresh `tests/fixtures/new-repo.sh full-config` repo, run `copilot --plugin-dir "$PLUGIN"`, then
record each outcome in the acceptance doc:

1. `/android-plan F1 feature` → `result: ready`; findings listed; the Figma link used and the UI
   question not asked; the made-up name, email and phone number appear nowhere in the ticket file.
2. `/android-plan F2 feature` → stops with the table. Rerun and give a reason → `result: waived`,
   the reason verbatim, repeated at gate 1. Move the `[BE]` to `QA TESTING` in Jira by hand, delete
   the ticket file, rerun → `result: ready`.
3. `/android-plan F3 feature` → the drop list; drop the unrelated key → `related.dropped`.
4. `/android-plan F4 feature` → `dead` flagged, stop.
5. `/android-plan F5 feature` → the Y/N question; N stops, Y records `android-only`.
6. `/android-plan B1 fix` → `no BE or UI tickets found`, continues.
7. Sign out of the Atlassian server in `/mcp`, then `/android-plan F1 feature` → the setup steps;
   give a reason → the manual intake, `result: jira-waived`.
8. In a `tests/fixtures/review-repo.sh defects` repo: `/android-review TA-1234`, answering Y →
   exactly the must-fix lines change; `android-lint` then fails for lack of Gradle and the stage
   stops. Record that it stopped rather than claiming a pass.
9. The full chain, on a PIXEL clone with a local bare remote:

   ```bash
   git clone -q /Users/ericcerio/Projects/Eplayment/eplayment-pixel-android /tmp/acceptance-pixel
   cd /tmp/acceptance-pixel && git init -q --bare /tmp/acceptance-remote.git
   git remote set-url origin /tmp/acceptance-remote.git   # nothing can reach the real remote
   ```

   Run `/android-onboard` if the clone has no `.ai/project/android-workflow.yml`. Then
   `/android-plan <F2 key> feature`, give a reason for the blocked `[BE]` (so a related waiver
   exists), approve the plan, and `/android-branch`. Add `response.body()!!` to an existing
   ViewModel's API call, then `/android-ship <F2 key>` → stops at 07b. Answer N, fix it by hand,
   rerun `/android-ship` → `versionName` is **not** bumped a second time; the review clears; the
   security gate runs; gate 3 quotes the related waiver. Answer no at gate 3. Then
   `rm -rf /tmp/acceptance-pixel /tmp/acceptance-remote.git`.

- [ ] **Step 3: Both suites, and personal paths**

```bash
cd "$PLUGIN" && ./tests/run.sh | tail -1 && ./tests/lint-skills.sh
grep -rn "/Users/" skills/ shared/ mcp.json || echo "no personal paths"
```
Expected: `22 passed, 0 failed`, `skill lint: OK`, `no personal paths`.

- [ ] **Step 4: Bump and commit**

Set `"version": "0.2.0"` in `plugin.json`.

```bash
git add plugin.json docs/checks/2026-09-22-acceptance-0.2.0.md
git commit -m "docs: acceptance run for 0.2.0

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: Stop and hand over — do not publish**

Report to the user the acceptance results, and that merging to `main` and tagging `v0.2.0` rolls
this out to every developer at their next `copilot plugin update`. Publishing waits for (a) the
user's explicit go and (b) R&D's and the DPO's answers to spec §10 (the tier, personal data in
tickets, the no-override block), recorded in the acceptance doc. Say that Android Studio is still
unverified for plugin MCP servers (check 7).

---

## Notes carried from the spec

- **Accepted risk:** the Atlassian server is declared in every Copilot session, not only in Android repositories (spec §10).
- **For R&D, not decided here:** the Agent-tier question, customer personal data in bug tickets, and the hard block with no human override (spec §10).
- **Out of scope:** writing to Jira; re-checking related tickets at push time; iOS or web tickets; shipping the R&D Handbook server in `mcp.json`; renumbering stages.
