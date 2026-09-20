# Android AI workflow for GitHub Copilot — design

**Status:** approved design, not yet built
**Date:** 2026-09-20
**Source:** `android-ai-workflow.html` (the Android AI Workflow deck), and the working Claude Code
workflow in `eplayment-pixel-android`

## 1. What this is

A GitHub Copilot plugin, published from this repository, that runs the ten-stage Android
development workflow described in the deck: intake, plan, branch, development, lint, release
notes and version, tests, security gate, commit and push, distribution note.

Two things differ from the deck's Claude Code workflow:

- **Every stage is a skill that can be run on its own.** Plan a fix without writing code; run tests
  for one feature; check security on the current diff. The full run is a chain over those same
  skills, so there is one copy of each stage.
- **The four rails are enforced by a hook**, not by instructions the model may or may not follow.

The three human gates from the deck are unchanged: the plan (stage 02), the security review
(stage 08), and the push (stage 09).

## 2. Why this is needed

### The Copilot workflow in PIXEL is broken

`eplayment-pixel-android` carries `.github/prompts/ticket.prompt.md` and `bugfix.prompt.md`, added
in `bbf470f8` (2026-06-24). Both tell Copilot to read seven files:

```
.ai/department/workflows-standard.md   .ai/department/context-awareness.md
.ai/department/branching.md            .ai/department/lint.md
.ai/department/versioning.md           .ai/department/security.md
.ai/department/distribution-note.md
```

None of them exist. Commit `6f6cfff7` (2026-09-04, "docs: unify AI context template") moved the
workflow modules from `.github/pixel-workflows/` into `.ai/department/`, and `.ai/department/` is
replaced wholesale on every `epm aics sync`. The modules were overwritten by the next sync. The
last complete set is the ten files in `.github/pixel-workflows/` at `6f6cfff7^`.

`develop` also carries `.claude/workflows/pixel`, a symlink to `../../.github/pixel-workflows`,
which no longer exists.

**Rule that follows:** nothing this workflow needs may live in `.ai/company/` or `.ai/department/`.
Per-repo settings go in `.ai/project/`, which the repository owns and sync never touches.

### The workflow does not survive a move between machines

Both prompts hardcode `JAVA_HOME=/Users/robcastro/Library/Java/JavaVirtualMachines/jbr-17.0.12/...`.
An earlier commit symlinked `.claude/commands` to `/Users/robcastro/pixel-claude/commands`. The
machine this design was written on has no standalone JDK at all — only Android Studio's bundled
JBR 21.0.10, which runs both repos fine (AGP 8.12.2, Gradle 8.13).

### Three other Android repos have nothing

Per the deck: `eplayment-android`, `keri-android`, `mannypay-android`. This design pilots the first
of them. `banking-app-mobile-develop` is Flutter and needs a different workflow.

## 3. Goals and non-goals

**Goals**

1. Run any stage on its own, in particular plan-only, test-one-feature, and security-only.
2. Run the whole workflow with one command, as today.
3. Each stage written once, shared by the feature and bugfix paths.
4. The four rails enforced deterministically.
5. Porting to another repo needs configuration, not edits to any skill.

**Non-goals**

- Claude Code parity. The `.claude/` workflow in PIXEL is left alone.
- Flutter, iOS, or backend variants.
- Opening PRs on the developer's behalf beyond what section 8.9 describes, running Fastlane, or
  touching `versionCode`.
- `keri-android` and `mannypay-android`.

## 4. Platform facts this design depends on

Verified on this machine, 2026-09-20: Copilot CLI **1.0.85**, Android Studio **2025.3.4** with
GitHub Copilot plugin **1.11.0**.

| Fact | Evidence |
|---|---|
| The Android Studio plugin bundles the same agent runtime as the CLI, including its plugin loader | `copilot-agent/dist/node_modules/@github/copilot/sdk/index.js` contains the `installed-plugins` directory resolver |
| Plugins are installed from a GitHub repo: `copilot plugin install owner/repo`, updated with `copilot plugin update --all`. There is no version pinning | `copilot plugin install --help`, `copilot plugin update --help` |
| Skills are discovered from `.github/skills/`, `.agents/skills/`, `.claude/skills/`, `~/.copilot/skills/`, `~/.agents/skills/`, and installed plugins | `copilot skill --help` |
| A plugin declaring the v1 `$schema` loads its hooks **only** from `com.github.copilot/hooks/hooks.json` | Verified 2026-09-20: the CLI logged an error and ignored `hooks/hooks.json` until it was moved |
| A hook entry is `{type: "command", bash, powershell, cwd, env, timeoutSec}` | hook config schema in the SDK |
| `preToolUse` receives `{sessionId, timestamp, cwd, toolName, toolArgs}` — `toolArgs` a nested **object** — and returns `{permissionDecision: "allow" / "deny" / "ask", permissionDecisionReason}`. A denial reaches the model as `Denied by preToolUse hook: <reason>` and it cannot override it | Verified 2026-09-20: `git push origin develop` was blocked |
| `postToolUse` exists alongside `preToolUse` | same |
| File-editing tools are named `edit`, `create`, `str_replace_editor`, `apply_patch` | SDK tool definitions |
| The CLI has a built-in `/security-review` that analyses staged and unstaged changes, plus `/review`, `/diff`, `/pr` | `copilot help commands` |

The shell tool is named **`bash`** (verified 2026-09-20; `skill` and `view` were also seen). The hook
still identifies a shell call by the `command` field in `toolArgs` rather than by name, so a renamed
or IDE-specific shell tool cannot slip past it. The file-editing names still come from the SDK and
are confirmed on the first real edit.

## 5. Shape

```
ai-workflow/                          the plugin repository
├─ plugin.json                        agent-plugins schema 1.0.0
├─ skills/
│  ├─ ticket/SKILL.md                 chain · plan → branch → develop → ship
│  ├─ bugfix/SKILL.md                 chain · the same, in fix mode
│  ├─ android-ship/SKILL.md           chain · stages 05→10
│  ├─ android-plan/                   stages 01+02 · gate 1
│  ├─ android-branch/                 stage 03
│  ├─ android-develop/                stage 04 · the developer's call
│  ├─ android-lint/                   stage 05
│  ├─ android-release-notes/          stage 06
│  ├─ android-test/                   stage 07
│  ├─ android-security-gate/          stage 08 · gate 2
│  ├─ android-commit-push/            stage 09 · gate 3
│  ├─ android-dist-note/              stage 10
│  └─ android-onboard/                writes a repo's config
├─ com.github.copilot/
│  └─ hooks/hooks.json                registers both hooks (required path)
├─ hooks/
│  ├─ guard-rails.sh                  preToolUse · the four rails
│  └─ post-edit.sh                    postToolUse · repo-local checks
├─ tests/
│  ├─ run.sh                          runs the cases below; no CI
│  └─ cases/                          sample tool calls with expected decisions
└─ docs/superpowers/specs/            this document
```

Each stage skill is a folder holding `SKILL.md` (the steps) and `reference.md` (the detailed
rules). The `reference.md` files are the modules recovered from `.github/pixel-workflows/` at
`6f6cfff7^`, with everything repo-specific taken out and read from configuration instead:

| Recovered module | Becomes |
|---|---|
| `context-awareness.md` | `android-plan/reference.md` |
| `branching.md` | `android-branch/reference.md` |
| `lint.md` | `android-lint/reference.md` |
| `versioning.md` | `android-release-notes/reference.md` |
| `security.md` | `android-security-gate/reference.md` |
| `distribution-note.md` | `android-dist-note/reference.md` |
| `architecture.md`, `conventions.md`, `ui-reference.md` | stay per-repo in `.ai/project/` |
| `README.md` | the chain skills |

The existing AICS files in this repository (`.ai/`, `AGENTS.md`, `CLAUDE.md`,
`.github/copilot-instructions.md`) stay as context for people editing the plugin.

### Skill naming

Chains keep the names the team already uses: `/ticket`, `/bugfix`. Stage skills are prefixed
`android-`. No built-in Copilot command collides with these.

## 6. The contract every stage skill follows

1. **Find its inputs.** Ticket key from the argument, else from the current branch name, else ask.
   Load `.ai/project/android-workflow.yml`; if absent, stop and say to run `/android-onboard`.
   Load the ticket file if one exists.
2. **Do the stage.**
3. **Stop at its gate**, if it has one.
4. **Record and hand off.** Write results to the ticket file; print a one-line summary and the next
   skill to run.

Because inputs are found rather than remembered, a skill behaves the same whether a chain called it
or a developer did.

### The ticket file

Path: `<git-common-dir>/android-workflow/<KEY>.md`, where `<git-common-dir>` is
`git rev-parse --git-common-dir`. It is never committed, never appears in `git status`, and is
shared by all worktrees of the repository.

```yaml
---
key: TA-1234
name: Subscription cancel reason
type: feature                 # feature | bugfix
branch: feature/TA-1234
architecture: MVVM            # features only
plan_approved: 2026-09-20T10:14+08:00
security:
  result: pass                # pass | fail | waived
  diff: 3f2a91c               # fingerprint of the changes reviewed
  waivers:
    - finding: "new dependency com.foo:bar"
      reason: "vendor SDK required by TA-1234, reviewed with the security owner"
pushed: 9c1e77a
workflow_version: 0.1.0
---
## Acceptance criteria
## Approved plan
```

Writers: `android-plan` (ticket fields, plan, approval), `android-branch` (branch),
`android-security-gate` (result and waivers), `android-commit-push` (pushed commit). Every other
skill only reads it.

The `diff` fingerprint is a hash of the changes reviewed (tracked diff against the merge base plus
staged and untracked files). `android-commit-push` recomputes it: if it does not match, the saved
pass no longer applies and the security gate runs again. Waivers expire the same way.

**Risk:** an agent may refuse to write inside `.git/`. Check 5 in section 10 settles it; if it
fails, the fallback is `.android-workflow/` at the repository root plus a `.gitignore` entry.

## 7. Per-repo configuration

One file per repository, `.ai/project/android-workflow.yml`. No skill contains a repository name,
path, or Gradle task.

```yaml
workflow_version: 0.1.0                 # plugin version this config was written for
app_tag: PIXEL                          # stage 10 header: [...][PIXEL]
jira_base: https://eplayment.atlassian.net/browse/
base_branch: develop
protected_branches: [develop, main, master]

build:
  gradle_file: app/build.gradle
  jdk: 17                               # minimum; resolved at run time
  lint_task: lintDebug
  test_task: testDebugUnitTest
  ktlint: none                          # none | gradle | cli

versioning:
  rule: patch-bump                      # patch-bump | branch-suffix

release_notes:
  file: FirebaseAppDistributionConfig/release_notes.txt
  mode: append                          # append (deduplicated) | replace

distribution:
  register_branch_in: none              # or a workflow file whose push.branches gets this branch
  open_draft_pr: true                   # offer the draft PR after a successful push

bugfix_branch_rule: ask                 # ask | batch | per-ticket

lint:
  post_edit_checks: []                  # scripts run by the postToolUse hook, advisory

security:
  guarded_files:                        # layer 1 of the security gate
    - app/src/main/cpp/NativeGuards.cpp
    - "**/ui/utils/security/ReverseEngineerUtils*"
    - "**/data/security/IntegrityService*"
    - "**/core/di/IntegrityModule*"
    - app/build.gradle                  # signing config, SIGNING_CERT_SHA256
  known_tracked_secrets:                # already in git; reported once, never a per-run failure
    - fastlane/firebase_credentials.json
```

**JDK resolution**, in order: `$JAVA_HOME` if it satisfies `build.jdk`; else
`/usr/libexec/java_home -v <jdk>+`; else Android Studio's bundled JBR
(`/Applications/Android Studio.app/Contents/jbr/Contents/Home`). No personal paths.

**The two pilot repositories:**

| Key | `eplayment-pixel-android` | `eplayment-android` |
|---|---|---|
| `versioning.rule` | `patch-bump` (3.4.27 → 3.4.28) | `branch-suffix` (`2.13.9-realtime-bank-transfer-status`) |
| `release_notes.mode` | `append` | `replace` |
| `register_branch_in` | `none` (its `distribute-develop.yml` already lists `feat/SB-20`, added by hand) | `.github/workflows/distribute-in-develop.yml` |
| `known_tracked_secrets` | `fastlane/firebase_credentials.json` | `app/eplayment-key.keystore`, `eplayment-keystore.jks` |
| `lint.post_edit_checks` | `.claude/hooks/check-hardcoded-strings.sh` | none |
| `app_tag` | `PIXEL` | confirmed during onboarding |
| `.ai/project/architecture.md` | exists | drafted by `/android-onboard` |
| AICS installed | yes | no — `epm aics install` runs first |

`versionCode` is never edited in either repository.

**Version drift** warns and never blocks: when the installed plugin is older than
`workflow_version`, a run prints one line suggesting `copilot plugin update`. Config fields stay
optional with defaults so an older plugin keeps working.

## 8. The stages

Gates stop and wait for an explicit reply. Stages without a gate do not pause.

### 8.1 `android-plan <KEY> [feature|fix]` — stages 01+02, gate 1

Intake, prompting one field at a time for anything missing: **name**, **key** (validated against
`<LETTERS>-<DIGITS>`), and **acceptance criteria** for a feature or **observed vs expected** for a
fix. A **UI reference or repro steps** is optional, asked once; "skip" is accepted and it never
blocks. A missing required field stops the run.

Then the three probes from `context-awareness.md`: code to reuse, the pattern already used in the
area (MVVM or MVI — features only; a fix follows what is there), and git and ticket state (dirty
tree, an existing branch for the key, the Jira URL already in the release notes).

It presents what to reuse, the architecture default, warnings, and the new files for a feature — or
the suspected cause, the files to change and the smallest fix for a bug. **Gate 1:** it waits for an
explicit go, then records the plan and the approval.

Run on its own, it stops there and prints the next step.

### 8.2 `android-branch` — stage 03

From `branching.md`: stay on the current branch if its name contains the key; on an epic branch
`feature/<topic>`, stack `<topic>/<key>` on it; otherwise `feature/<key>` off `base_branch`.

Bugfixes follow `bugfix_branch_rule`. With `ask` (the default): stay on the current `bugfix/*`
branch if there is one, else ask, offering the newest `bugfix/*` branch on the remote and
`bugfix/<KEY>`. Both conventions are in use today — `bugfix/TA-1060` and `bugfix/antimony`.

A dirty tree is surfaced and the developer decides.

### 8.3 `android-develop` — stage 04, the developer's call

Requires an approved plan in the ticket file; without one it sends the developer to
`/android-plan`. A feature reuses what stage 02 found, or scaffolds from the repository's
`.ai/project/architecture.md`, wiring `ViewModel → UseCase(Imp) → Repository → Api`, routes and DI.
A fix makes the smallest correct change in the existing pattern. Either way it runs the Compose
checker afterwards.

In a chain this stage is offered as **Y/N**. Calling the skill directly is a Y. On **N** the chain
stops after branching and says: write the code, then run `/android-ship`.

### 8.4 `android-lint` — stage 05

ktlint according to `build.ktlint` (`none` degrades to applying the rules by hand and says so in
the summary), then `build.lint_task`, then the sanitation checklist — on changed files, not the
tree. Files it reformats are re-staged. It reports what ran and what was skipped.

### 8.5 `android-release-notes` — stage 06

Applies `versioning.rule` to `versionName` in `build.gradle_file`, and `release_notes.mode` to
`release_notes.file` using `jira_base` + key. Registers the branch in
`distribution.register_branch_in` when set. Never touches `versionCode`.

### 8.6 `android-test [scope]` — stage 07

No scope: tests related to the changed files. A scope (`subscriptions`, a package, or a class) is
matched case-insensitively against test class names and package paths; it lists what matched, then
runs the filtered `build.test_task`, for example
`./gradlew testDebugUnitTest --tests '*Subscription*'`. No match means it says so and offers near
matches rather than running everything; `--all` runs everything.

In a feature chain it writes or adjusts fake-driven `…ViewModelTest` style tests
(`UnconfinedTestDispatcher`, `runTest`, fake use cases). In a fix chain it runs the existing tests;
a cheap regression test is welcome, not required. Run on its own it only runs tests unless asked.

**It never reports a pass without the command output.**

### 8.7 `android-security-gate` — stage 08, gate 2

Four layers, from `security.md`:

1. **Hard rails** — `security.guarded_files` may not change without explicit confirmation.
2. **Diff scan** — hardcoded secrets, API keys and tokens; personal data in `Log.*`; new or changed
   manifest permissions; new dependencies; plaintext token handling that bypasses `SessionManager`
   or `EncryptionHelper`; weakened certificate pinning or integrity checks.
3. **Audit pass** — the change does not weaken hardening: tokens still flow through the encrypted
   session manager, new API calls carry their auth header, integrity and root-detection paths are
   untouched, no new networking bypasses the pinned client.
4. **Review** — the CLI's built-in `/security-review` where available; otherwise the checklist
   written into the skill (Android Studio).

Files in `security.known_tracked_secrets` are reported once as open issues and never fail a run.

**Gate 2:** high-severity findings block the push until fixed, or waived with a written reason. A
waiver is recorded per finding against the current diff fingerprint, expires when the code changes,
and is repeated in the push summary so it reaches the reviewer.

### 8.8 `android-commit-push` — stage 09, gate 3

Refuses to run on a protected branch. Recomputes the diff fingerprint and reruns the security gate
if the recorded pass no longer applies. Shows the exact message `<KEY>: <name>`, the files, and
`<branch> → <remote>`, then stops.

**Gate 3:** one confirmation covers staging, committing and pushing. Nothing is staged before it.
No attribution trailers in the message. Never force-pushes.

### 8.9 Draft PR — after the push

`distribution.open_draft_pr` defaults to true, and the skill offers the draft PR against
`base_branch` after a successful push. A skill cannot type a CLI slash command, and `gh` is not
installed on the dev machines, so unless check 6 (section 10) finds a way to create it directly,
"offer" means handing the developer the exact `/pr` command in the CLI, or the compare link in
Android Studio.

**This diverges from the deck**, which says the workflow never opens the PR. The divergence is
deliberate: the deck's rollout wants a draft PR up as soon as the branch is pushed, and lists
"no `gh` on the dev machines" as something to wire up.

### 8.10 `android-dist-note` — stage 10

Asks prod or QA, then prints
`[FOR <PROD|QA> TESTING][Android][<versionName> (<versionCode>)][<app_tag>]` followed by the Jira
URLs from the release notes file, in file order. Output only; no files and no git.

### 8.11 The chains

- `/ticket <KEY>`: plan (feature) → branch → **Y/N** → develop → `android-ship`.
- `/bugfix <KEY>`: the same in fix mode.
- `/android-ship`: lint → release notes → tests → security gate → commit and push → distribution
  note, stopping at the first failure.

Rerunning a chain reads the ticket file and resumes at the first unfinished stage.

## 9. Hooks

`com.github.copilot/hooks/hooks.json` registers both hooks. Both are plain bash with no `jq` or Python dependency, and
both are inert unless the working directory is in a repository that has
`.ai/project/android-workflow.yml` — the plugin is installed per developer and must not interfere
with unrelated projects.

### 9.1 `preToolUse` — the four rails

A shell call is recognised by a `command` field in `toolArgs`; a file edit by the tool names `edit`,
`create`, `str_replace_editor`, `apply_patch`.

| Rail | Denied when |
|---|---|
| No commit or push to a protected branch | `git push` whose target is in `protected_branches`, or with no target while HEAD is on one; `git commit` while HEAD is on one |
| No force-push | `git push` with `-f`, `--force`, `--force-with-lease`, or a `+ref` target |
| No `versionCode` change | a file edit touching a `versionCode` line in `build.gradle_file`, or a shell command that rewrites one (`sed -i`, `perl -pi`, a redirect) |
| No secrets committed | `git add` naming a file matching `*.jks`, `*.keystore`, `*.p12`, `*.pem`, `*credentials*.json`, `local.properties`, `keystore.properties`; or `git add -A`, `git add .`, `git commit -a` while such a file has uncommitted changes |

Each denial names the rail and the fix, for example: *"Blocked: `develop` is protected. Push to
`feature/TA-1234` instead."*

The hook returns `deny` or nothing. It does **not** return `ask`: `android-commit-push` already
confirms once before staging, and the deck promises one confirmation per push.

**On its own failure** (crash or timeout) it denies writing git commands — `push`, `commit`, `add`,
`reset` — and allows everything else.

### 9.2 `postToolUse` — repo-local checks

After a file edit, runs each script in `lint.post_edit_checks` with the edited file path as its
first argument. Advisory: output is reported, nothing is blocked.

PIXEL's `.claude/hooks/check-hardcoded-strings.sh` is the first consumer. It currently reads
Claude's payload from stdin through `jq`; the pilot PR gives it `${1:-}` as the file path and falls
back to the payload, so it keeps working for Claude Code.

## 10. Checks before building

In order. Checks 1 and 5 have fallbacks; check 3 decides how the chains call stage skills.

1. **A plugin installed by the CLI is visible in Android Studio.** Install a hello-world plugin and
   confirm its skill appears in Android Studio agent mode. *Fallback if it fails: v1 is CLI-only,
   run from Android Studio's terminal; nothing is copied into repositories.*
2. **Plugin hooks fire in both surfaces and can deny.** Confirm `git push origin develop` is
   blocked. Log the real tool names, especially the shell tool.
3. **One skill can call another** (`/ticket` calling `android-plan`) in CLI 1.0.85 and Android
   Studio 1.11.0. *Fallback: chains read each stage's `SKILL.md` by path; standalone use is
   unaffected.*
4. **A skill can read a sibling skill's file** from the installed plugin directory.
5. **Writes inside `.git/` are allowed.** *Fallback: `.android-workflow/` plus `.gitignore`.*
6. **Whether anything can open a draft PR without `gh`.** Decides what 8.9 does.

## 11. Testing

No CI. Verification is:

| Level | What |
|---|---|
| `tests/run.sh` | About 15 sample tool calls against a scratch git repository: push to `develop`, force-push, `versionCode` edit, `git add` of a keystore, `git add .` with a dirty secret, plus ordinary commands that must pass. Run before tagging a version. Written before the hook. |
| Skill lint | A script asserting each skill has name and description frontmatter, that every referenced file exists, and that no skill contains a repository name (`PIXEL`, `eplayment-*`), a `/Users/` path, or a configuration value used as anything but a worked example. |
| Manual acceptance | On a PIXEL clone whose remote is a local bare repository, in both surfaces where check 1 allows: plan-only; test one feature; security-only; a full `/ticket`; the N path followed by `/android-ship`. |

## 12. Rollout

1. **Publish.** Push this repository to a private `eplayment/ai-workflow`, tag `v0.1.0`. Developers
   run `copilot plugin install eplayment/ai-workflow` once, then `copilot plugin update --all`.
2. **PIXEL.** Install, run `/android-onboard`, and open one PR that adds
   `.ai/project/android-workflow.yml`, tweaks `check-hardcoded-strings.sh`, and deletes
   `.github/prompts/ticket.prompt.md`, `.github/prompts/bugfix.prompt.md` and the dangling
   `.claude/workflows/pixel` symlink. Then take one real ticket end to end.
3. **eplayment-android.** `epm aics install`, then `/android-onboard`, review the drafted
   `architecture.md` and `conventions.md`, open the PR, then do one real bugfix.

**Done when:** eplayment-android works with **no edits to any skill** — only its `.yml` and
`.ai/project` documents; plan-only, test-one-feature and security-only all work; the hook blocks
all four rails; and no personal path appears anywhere in the plugin.

### `/android-onboard`

1. Checks for `.ai/`; offers to run `epm aics install` and waits for a yes.
2. Reads the repository: Gradle file and build types (lint and test tasks), whether ktlint is
   wired in, the version rule (from past `versionName` changes), the release-notes mode (from that
   file's history), workflows listing feature branches, and secret-looking files tracked in git.
3. Writes `.ai/project/android-workflow.yml`, plus draft `architecture.md` and `conventions.md`
   when missing.
4. Asks about anything it could not settle, then shows what it wrote. It does not commit.
5. Reports legacy workflow files that can be deleted.

## 13. Accepted risks and out of scope

**Accepted risk — registration.** The deck's open items say a new AI workflow goes into the AI and
Agents Registry, with its L2 handling note, before other teams use it. The decision here is to
track that separately and let it block nothing, so `eplayment-android` may adopt this workflow
before the entry exists. Recorded deliberately, not overlooked.

**Tracked separately — committed secrets.** These need rotating regardless of this plan:
`fastlane/firebase_credentials.json` in PIXEL (tracked despite `.gitignore`; an ignore rule does not
untrack an existing file), and `app/eplayment-key.keystore` and `eplayment-keystore.jks` in
`eplayment-android`. A committed signing key may require a Play upload-key reset. This plan only
lists them in `known_tracked_secrets` so the gate reports them once instead of failing every run.

**Out of scope:** wiring `org.jlleitschuh.gradle.ktlint` into either build; installing `gh`; a Figma
dev seat; Claude Code parity; `keri-android` and `mannypay-android`; the Flutter variant.
