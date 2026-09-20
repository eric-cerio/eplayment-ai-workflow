# Android Copilot Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a GitHub Copilot plugin in this repository that runs the ten-stage Android workflow, where every stage is a skill that can also be run on its own, and the four rails are enforced by a hook.

**Architecture:** One plugin (`plugin.json` + `skills/` + `hooks/`) installed per developer from a private GitHub repo. Thirteen skills: three chains (`/ticket`, `/bugfix`, `/android-ship`) over nine stage skills plus `/android-onboard`. Per-repo settings live in each Android repo's `.ai/project/android-workflow.yml`; per-ticket run state lives in `<git-common-dir>/android-workflow/<KEY>.md`. A `preToolUse` hook denies the four rails; a `postToolUse` hook runs repo-local checks.

**Tech Stack:** Markdown skills (Copilot Agent Skills), bash (hooks + tests, no `jq`/Python), GitHub Copilot CLI 1.0.85, Android Studio 2025.3.4 with Copilot plugin 1.11.0, target repos use AGP 8.12.2 / Gradle 8.13.

**Spec:** `docs/superpowers/specs/2026-09-20-android-copilot-workflow-design.md`

## Global Constraints

- **No skill may contain** a repository name (`PIXEL`, `eplayment-*`), a `/Users/` path, or a Gradle task name outside a worked example. Everything repo-specific is read from `.ai/project/android-workflow.yml`.
- **Nothing this workflow needs may live in `.ai/company/` or `.ai/department/`** — `epm aics sync` replaces both wholesale.
- **Hooks are plain bash.** No `jq`, no Python: they are not guaranteed on the dev machines.
- **Hooks are inert** unless the working directory is inside a git repo containing `.ai/project/android-workflow.yml`.
- **Never** change `versionCode`, force-push, commit or push to `develop`/`main`/`master`, or commit secrets or keystores.
- **Gates:** stage 02 plan, stage 08 security, stage 09 push. Each stops and waits for an explicit reply.
- **Commit messages** are `<KEY>: <name>` with no attribution trailers. Commits in *this* repo are normal conventional commits (`feat:`, `test:`, `docs:`).
- **JDK resolution order everywhere:** `$JAVA_HOME` if it satisfies `build.jdk` → `/usr/libexec/java_home -v <jdk>+` → `/Applications/Android Studio.app/Contents/jbr/Contents/Home`.
- **Local plugin testing:** `copilot --plugin-dir "$PWD"` loads this plugin without publishing. Non-interactive runs need `--allow-all-tools`; `--no-ask-user` disables the ask_user tool.
- **Skill frontmatter** is `name`, `description`, and optionally `allowed-tools` (see any skill under `~/.copilot/installed-plugins/`).
- **Recovered module source:** `git -C /Users/ericcerio/Projects/Eplayment/eplayment-pixel-android show 6f6cfff7^:.github/pixel-workflows/<file>`.
- **Never write credential-shaped content into this repo**, not even as a test fixture. Secret-path fixtures are created empty, and any secret-shaped literal a test needs is generated at run time. This repo's own pre-write hook enforces it, correctly.

## File Structure

| Path | Responsibility |
|---|---|
| `plugin.json` | Plugin manifest (agent-plugins schema 1.0.0) |
| `README.md` | Install, update, what each skill does |
| `shared/config.md` | The config schema, JDK resolution, how skills read config |
| `shared/ticket-file.md` | Ticket-file location, format, who writes what |
| `skills/ticket/SKILL.md` | Chain: plan → branch → develop → ship (feature) |
| `skills/bugfix/SKILL.md` | Chain: the same in fix mode |
| `skills/android-ship/SKILL.md` | Chain: stages 05→10 |
| `skills/android-plan/{SKILL,reference}.md` | Stages 01+02, gate 1 |
| `skills/android-branch/{SKILL,reference}.md` | Stage 03 |
| `skills/android-develop/{SKILL,reference}.md` | Stage 04 |
| `skills/android-lint/{SKILL,reference}.md` | Stage 05 |
| `skills/android-release-notes/{SKILL,reference}.md` | Stage 06 |
| `skills/android-test/{SKILL,reference}.md` | Stage 07 |
| `skills/android-security-gate/{SKILL,reference}.md` | Stage 08, gate 2 |
| `skills/android-commit-push/{SKILL,reference}.md` | Stage 09, gate 3, draft-PR offer |
| `skills/android-dist-note/{SKILL,reference}.md` | Stage 10 |
| `skills/android-onboard/{SKILL,reference}.md` | Writes a repo's config |
| `com.github.copilot/hooks/hooks.json` | Registers both hooks (required path for v1-schema plugins) |
| `hooks/lib.sh` | Payload parsing, config reading, allow/deny helpers |
| `hooks/guard-rails.sh` | preToolUse: the four rails |
| `hooks/post-edit.sh` | postToolUse: repo-local checks |
| `tests/run.sh` | Runs every case in `tests/cases/` |
| `tests/cases/*.case` | One payload + expectation per file |
| `tests/fixtures/new-repo.sh` | Builds a scratch Android-shaped git repo |
| `tests/lint-skills.sh` | Skill frontmatter, references, and forbidden-string lint |
| `docs/checks/2026-09-20-platform-checks.md` | Findings from Task 1 |

---

### Task 1: Platform checks — DONE except check 1

> Ran 2026-09-20. Findings: `docs/checks/2026-09-20-platform-checks.md`. Checks 2-6 are settled; check 1 (Android Studio) still needs a person at the IDE.

The six checks from spec §10. Nothing else is built until their findings are written down, because checks 1, 3 and 5 each have a fallback that changes later tasks.

**Files:**
- Create: `docs/checks/2026-09-20-platform-checks.md`
- Create: `/tmp/hello-plugin/plugin.json`, `/tmp/hello-plugin/skills/hello-android/SKILL.md`, `/tmp/hello-plugin/skills/hello-caller/SKILL.md`, `/tmp/hello-plugin/hooks/hooks.json`, `/tmp/hello-plugin/hooks/deny.sh`

**Interfaces:**
- Produces: findings that later tasks read — `AS_PLUGIN_VISIBLE` (yes/no), `HOOKS_FIRE` (yes/no per surface), `SKILL_CALLS_SKILL` (yes/no), `SIBLING_FILE_READ` (yes/no), `GIT_DIR_WRITABLE` (yes/no), `DRAFT_PR_WITHOUT_GH` (how, if at all), and the **shell tool name** in each surface.

- [ ] **Step 1: Build the throwaway plugin**

```bash
mkdir -p /tmp/hello-plugin/skills/hello-android /tmp/hello-plugin/skills/hello-caller /tmp/hello-plugin/hooks /tmp/hello-plugin/com.github.copilot/hooks
cat > /tmp/hello-plugin/plugin.json <<'JSON'
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "hello-android",
  "version": "0.0.1",
  "description": "Throwaway plugin used to verify Copilot plugin behaviour."
}
JSON
cat > /tmp/hello-plugin/skills/hello-android/SKILL.md <<'MD'
---
name: hello-android
description: Verification skill. Use when the user types /hello-android. Prints a marker and reads its sibling file.
---
# hello-android
1. Print exactly: `HELLO-ANDROID-OK`.
2. Read `../hello-caller/SKILL.md` (relative to this file) and print its `name:` line. If you cannot read it, print `SIBLING-READ-FAILED`.
3. Write the text `git-dir-write-ok` to `<git-common-dir>/android-workflow/check.txt`, creating the directory (`git rev-parse --git-common-dir`). If refused or blocked, print `GIT-DIR-WRITE-FAILED`.
MD
cat > /tmp/hello-plugin/skills/hello-caller/SKILL.md <<'MD'
---
name: hello-caller
description: Verification skill. Use when the user types /hello-caller. Calls the hello-android skill.
---
# hello-caller
1. Invoke the `hello-android` skill and let it run to completion.
2. Then print exactly: `CALLER-OK`.
MD
cat > /tmp/hello-plugin/com.github.copilot/hooks/hooks.json <<'JSON'
{ "hooks": { "preToolUse": [ { "type": "command", "bash": "./hooks/deny.sh", "timeoutSec": 10 } ] } }
JSON
cat > /tmp/hello-plugin/hooks/deny.sh <<'SH'
#!/usr/bin/env bash
set -u
payload="$(cat)"
printf '%s\n' "$payload" >> /tmp/hello-plugin-hook.log
case "$payload" in
  *"git push"*) printf '{"permissionDecision":"deny","permissionDecisionReason":"hello-plugin check: push blocked"}\n' ;;
  *) printf '{}\n' ;;
esac
SH
chmod +x /tmp/hello-plugin/hooks/deny.sh
```

- [ ] **Step 2: Check 2 and the shell tool name, in the CLI**

```bash
cd /tmp && rm -f /tmp/hello-plugin-hook.log
copilot -p "/hello-android" --plugin-dir /tmp/hello-plugin --allow-all-tools --no-ask-user
copilot -p "Run: git push origin develop" --plugin-dir /tmp/hello-plugin --allow-all-tools --no-ask-user
grep -o '"toolName":"[^"]*"' /tmp/hello-plugin-hook.log | sort -u
```
Expected: `HELLO-ANDROID-OK` in the first run; the second refused with "hello-plugin check: push blocked". Record every `toolName` seen — the shell tool's name is what the rails must recognise if name-matching is ever preferred over argument-matching.

- [ ] **Step 3: Checks 3, 4 and 5 in the CLI**

```bash
cd /Users/ericcerio/Projects/Eplayment/ai-workflow
copilot -p "/hello-caller" --plugin-dir /tmp/hello-plugin --allow-all-tools --no-ask-user
git rev-parse --git-common-dir   # then check for android-workflow/check.txt under it
```
Expected: `HELLO-ANDROID-OK` then `CALLER-OK` (check 3 passes); the `name:` line printed rather than `SIBLING-READ-FAILED` (check 4); `check.txt` present (check 5).

- [ ] **Step 4: Check 1 in Android Studio**

Install the plugin where the IDE also reads plugins:

```bash
cp -R /tmp/hello-plugin ~/.copilot/installed-plugins/local/hello-android
```
Open Android Studio 2025.3.4 → Copilot Chat → agent mode → type `/hello-android`. Record whether the skill appears and runs, and whether `/tmp/hello-plugin-hook.log` grows when you ask it to run a shell command (check 2 in the IDE).

- [ ] **Step 5: Check 6 — draft PR without `gh`**

In a CLI session inside a repo with a pushed branch, ask: *"open a draft pull request against develop"*. Record whether any tool can do it (and its name), or whether the only path is the developer typing `/pr`.

- [ ] **Step 6: Write the findings**

Create `docs/checks/2026-09-20-platform-checks.md` with one section per check: what was run, the observed output, and the decision it settles. State explicitly:
- If check 1 failed → **v1 is CLI-only**; skip every Android Studio step in later tasks and say so in `README.md`.
- If check 3 failed → chains **read** each stage's `SKILL.md` by path instead of invoking it (Task 15 has both variants).
- If check 5 failed → the ticket file moves to `.android-workflow/` at the repo root and Task 6 adds a `.gitignore` line to the onboarding output.

- [ ] **Step 7: Clean up and commit**

```bash
rm -rf ~/.copilot/installed-plugins/local/hello-android /tmp/hello-plugin /tmp/hello-plugin-hook.log
git add docs/checks/2026-09-20-platform-checks.md
git commit -m "docs: record Copilot platform checks for the Android workflow plugin"
```

---

### Task 2: Plugin skeleton and the skill lint

A plugin that installs, one trivially safe skill (stage 10, which only prints), and the lint that every later skill must pass. Written lint-first.

**Files:**
- Create: `plugin.json`, `README.md`, `tests/lint-skills.sh`
- Create: `skills/android-dist-note/SKILL.md`, `skills/android-dist-note/reference.md`

**Interfaces:**
- Produces: `tests/lint-skills.sh` (exit 0 = clean, non-zero + one line per violation), and the skill-folder convention `skills/<name>/SKILL.md` + optional `reference.md` that every later task follows.

- [ ] **Step 1: Write the lint**

```bash
mkdir -p tests
cat > tests/lint-skills.sh <<'SH'
#!/usr/bin/env bash
# Lints every skill: frontmatter, referenced files exist, no repo-specific strings.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
note() { printf '%s\n' "$1"; fail=1; }

for skill in "$root"/skills/*/SKILL.md; do
  [ -e "$skill" ] || { note "no skills found"; break; }
  dir="$(dirname "$skill")"
  rel="${skill#"$root"/}"

  head -1 "$skill" | grep -qx -- '---' || note "$rel: missing frontmatter opening ---"
  grep -qE '^name: [a-z0-9-]+$' "$skill" || note "$rel: missing or malformed 'name:'"
  grep -qE '^description: .{40,}$' "$skill" || note "$rel: 'description:' missing or shorter than 40 chars"
  [ "$(basename "$dir")" = "$(sed -n 's/^name: //p' "$skill" | head -1)" ] || note "$rel: folder name and 'name:' differ"

  # Referenced sibling/shared files must exist.
  grep -oE '(\.\./)+[A-Za-z0-9_./-]+\.md' "$skill" | sort -u | while read -r ref; do
    [ -e "$dir/$ref" ] || note "$rel: references missing file $ref"
  done

  # Repo-specific strings are configuration, not skill content.
  grep -nE '/Users/|eplayment-pixel-android|eplayment-android|keri-android|mannypay-android' "$skill" \
    && note "$rel: contains a repo-specific path or repo name"
done

[ $fail -eq 0 ] && echo "skill lint: OK"
exit $fail
SH
chmod +x tests/lint-skills.sh
```

- [ ] **Step 2: Run the lint to watch it fail**

Run: `./tests/lint-skills.sh`
Expected: FAIL, printing `no skills found`.

- [ ] **Step 3: Write the manifest and README**

```bash
cat > plugin.json <<'JSON'
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "android-workflow",
  "version": "0.1.0",
  "description": "Eplayment Android development workflow for Copilot: plan, branch, lint, version, test, security gate, commit and push, distribution note. Every stage runs on its own, or as one chain with /ticket and /bugfix.",
  "keywords": ["android", "kotlin", "gradle", "workflow", "jira"]
}
JSON
```

`README.md` covers: install (`copilot plugin install eplayment/ai-workflow`), update (`copilot plugin update --all`), the skill table (13 rows: name → what it does → gate, if any), the per-repo config pointer to `shared/config.md`, and running `./tests/run.sh` and `./tests/lint-skills.sh` before tagging. If Task 1 found Android Studio cannot see plugin skills, say so under a "Supported surfaces" heading.

- [ ] **Step 4: Write the stage 10 skill**

```bash
mkdir -p skills/android-dist-note
git -C /Users/ericcerio/Projects/Eplayment/eplayment-pixel-android show \
  6f6cfff7^:.github/pixel-workflows/distribution-note.md > skills/android-dist-note/reference.md
```

Then edit `reference.md`: replace the hardcoded `[PIXEL]` tag with `<app_tag>` from config, and the hardcoded release-notes path with `release_notes.file`. Keep the worked example, relabelling it as an example.

```markdown
---
name: android-dist-note
description: Produce the copy-pasteable Android test-distribution note for a build (the [FOR QA TESTING][Android][version][APP] block followed by the Jira links). Use when the user asks for the distribution note, the tester announcement, the QA note, or after a build has been pushed for testing. Stage 10 of the Android workflow.
---

# Distribution note — stage 10

Read `../../shared/config.md` first, then `reference.md` in this folder.

1. Read `app_tag`, `release_notes.file` and `build.gradle_file` from `.ai/project/android-workflow.yml`.
   No config → stop and tell the user to run `/android-onboard`.
2. Ask whether this is **PROD** or **QA** testing. Nothing else in this skill asks anything.
3. Read `versionName` and `versionCode` from `build.gradle_file`.
4. Read every line of `release_notes.file`, in file order.
5. Print one fenced block: the header `[FOR <PROD|QA> TESTING][Android][<versionName> (<versionCode>)][<app_tag>]`
   followed by the Jira URLs, one per line.

**This skill changes no files and runs no git commands.** If asked to, refuse and say so.
```

- [ ] **Step 5: Run the lint to verify it passes**

Run: `./tests/lint-skills.sh`
Expected: `skill lint: OK`, exit 0.

- [ ] **Step 6: Smoke-test the skill against a real repo**

```bash
cd /Users/ericcerio/Projects/Eplayment/eplayment-pixel-android
copilot -p "/android-dist-note (QA)" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools
git status --porcelain   # must be empty: the skill changes nothing
```
Expected: it stops and says the repo has no `.ai/project/android-workflow.yml` and to run `/android-onboard` (that config arrives in Task 6). `git status` stays clean.

- [ ] **Step 7: Commit**

```bash
cd /Users/ericcerio/Projects/Eplayment/ai-workflow
git add plugin.json README.md tests/lint-skills.sh skills/android-dist-note
git commit -m "feat: plugin skeleton, skill lint, and the distribution-note skill"
```

---

### Task 3: The guard-rails hook

The four rails, written test-first. This is the one component that can block a developer's git commands, so it gets the fixture-driven test suite.

**Files:**
- Create: `hooks/lib.sh`, `hooks/guard-rails.sh`, `com.github.copilot/hooks/hooks.json`
- Create: `tests/run.sh`, `tests/fixtures/new-repo.sh`, `tests/cases/*.case` (17 files)

**Interfaces:**
- Consumes: Task 1's findings. Confirmed 2026-09-20: the shell tool is named `bash`, and `toolArgs` is a nested object.
- Produces: `hooks/lib.sh` functions used by Task 4 — `payload_field <payload> <key>`, `payload_args <payload>`, `arg_field <args> <key>`, `allow`, `deny <reason>`, `repo_root <cwd>`, `has_workflow_config <repo_root>`, `current_branch <repo_root>`, `cfg_list <file> <key>`.

- [ ] **Step 1: Write the fixture builder**

The fixture needs a file on a secret-looking path. It is created **empty** — the rail matches the path, never the contents — so no credential-shaped text enters this repo.

```bash
mkdir -p tests/fixtures tests/cases
cat > tests/fixtures/new-repo.sh <<'SH'
#!/usr/bin/env bash
# Builds a scratch Android-shaped repo. Usage: new-repo.sh <variant>
# Variants: on-develop | on-feature | dirty-secret | no-config | with-post-edit-check
set -eu
variant="${1:-on-feature}"
dir="$(mktemp -d)"
cd "$dir"
git init -q -b develop .
git config user.email t@example.com
git config user.name Test
mkdir -p app/src/main/java/ui fastlane .ai/project scripts
printf 'android {\n  defaultConfig {\n    versionCode 60\n    versionName "3.4.27"\n  }\n}\n' > app/build.gradle
: > fastlane/firebase_credentials.json          # empty on purpose: the rail matches the path
printf 'package ui\n' > app/src/main/java/ui/Screen.kt
if [ "$variant" != "no-config" ]; then
  printf 'protected_branches: [develop, main, master]\nbuild:\n  gradle_file: app/build.gradle\n' \
    > .ai/project/android-workflow.yml
fi
if [ "$variant" = "with-post-edit-check" ]; then
  printf '#!/usr/bin/env bash\nprintf "post-edit-check-ran %%s\\n" "$1"\n' > scripts/check.sh
  chmod +x scripts/check.sh
  printf 'lint:\n  post_edit_checks: [scripts/check.sh]\n' >> .ai/project/android-workflow.yml
fi
git add -A >/dev/null
git commit -qm "initial"
git branch feature/TA-1234
case "$variant" in
  on-feature|with-post-edit-check) git checkout -q feature/TA-1234 ;;
  dirty-secret) git checkout -q feature/TA-1234
                printf 'changed\n' > fastlane/firebase_credentials.json ;;
esac
printf '%s\n' "$dir"
SH
chmod +x tests/fixtures/new-repo.sh
```

- [ ] **Step 2: Write the test runner**

```bash
cat > tests/run.sh <<'SH'
#!/usr/bin/env bash
# Runs every tests/cases/*.case against hooks/guard-rails.sh (or the hook named in the case).
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0
for case_file in "$root"/tests/cases/*.case; do
  name="$(basename "$case_file" .case)"
  expect="$(sed -n 's/^# expect: //p' "$case_file" | head -1)"
  match="$(sed -n 's/^# match: //p' "$case_file" | head -1)"
  fixture="$(sed -n 's/^# fixture: //p' "$case_file" | head -1)"
  hook="$(sed -n 's/^# hook: //p' "$case_file" | head -1)"; hook="${hook:-guard-rails.sh}"
  dir=""; [ -n "$fixture" ] && dir="$("$root/tests/fixtures/new-repo.sh" "$fixture")"
  payload="$(grep -v '^# ' "$case_file" | sed "s#\$FIXTURE#${dir}#g")"
  out="$(printf '%s' "$payload" | "$root/hooks/$hook" 2>&1)"
  decision="allow"
  case "$out" in *'"deny"'*) decision="deny" ;; esac
  ok=1
  [ "$decision" = "$expect" ] || ok=0
  if [ -n "$match" ]; then case "$out" in *"$match"*) ;; *) ok=0 ;; esac; fi
  if [ $ok -eq 1 ]; then pass=$((pass+1)); else
    fail=$((fail+1)); printf 'FAIL %s\n  expected: %s %s\n  got: %s\n' "$name" "$expect" "$match" "$out"
  fi
  [ -n "$dir" ] && rm -rf "$dir"
done
printf '%d passed, %d failed\n' "$pass" "$fail"
[ $fail -eq 0 ]
SH
chmod +x tests/run.sh
```

- [ ] **Step 3: Write the 17 cases**

Each file is comment lines then the payload. Two examples in full:

```bash
cat > tests/cases/push-to-develop-explicit.case <<'CASE'
# expect: deny
# match: protected
# fixture: on-feature
{"sessionId":"s","timestamp":0,"cwd":"$FIXTURE","toolName":"bash","toolArgs":{"command":"git push origin develop"}}
CASE

cat > tests/cases/edit-versioncode.case <<'CASE'
# expect: deny
# match: versionCode
# fixture: on-feature
{"sessionId":"s","timestamp":0,"cwd":"$FIXTURE","toolName":"str_replace_editor","toolArgs":{"path":"$FIXTURE/app/build.gradle","old_str":"versionCode 60","new_str":"versionCode 61"}}
CASE
```

Write the remaining 15 the same way:

| Case | command or edit | fixture | expect | match |
|---|---|---|---|---|
| `push-no-target-on-develop` | `git push` | on-develop | deny | protected |
| `push-feature-branch` | `git push origin feature/TA-1234` | on-feature | allow | |
| `force-push-short` | `git push -f origin feature/TA-1234` | on-feature | deny | force |
| `force-push-long` | `git push --force origin feature/TA-1234` | on-feature | deny | force |
| `force-with-lease` | `git push --force-with-lease` | on-feature | deny | force |
| `push-plus-refspec` | `git push origin +feature/TA-1234` | on-feature | deny | force |
| `commit-on-develop` | `git commit -m "x"` | on-develop | deny | protected |
| `commit-on-feature` | `git commit -m "TA-1234: x"` | on-feature | allow | |
| `edit-versionname` | `str_replace_editor` on `app/build.gradle`, `versionName "3.4.27"` → `"3.4.28"` | on-feature | allow | |
| `sed-versioncode` | `sed -i '' 's/versionCode 60/versionCode 61/' app/build.gradle` | on-feature | deny | versionCode |
| `git-add-keystore` | `git add app/release.keystore` | on-feature | deny | secret |
| `git-add-dot-dirty-secret` | `git add .` | dirty-secret | deny | firebase_credentials.json |
| `git-add-dot-clean` | `git add .` | on-feature | allow | |
| `gradle-command` | `./gradlew testDebugUnitTest` | on-feature | allow | |
| `outside-configured-repo` | `git push origin develop` | no-config | allow | |

- [ ] **Step 4: Run the suite to watch it fail**

Run: `./tests/run.sh`
Expected: FAIL — every case errors because `hooks/guard-rails.sh` does not exist.

- [ ] **Step 5: Write the shared library**

```bash
mkdir -p hooks
cat > hooks/lib.sh <<'SH'
#!/usr/bin/env bash
# Shared helpers for the Copilot hooks. No jq, no python.

allow() { printf '{}\n'; exit 0; }
deny()  { printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$(printf '%s' "$1" | sed 's/"/\\"/g')"; exit 0; }

# payload_field <payload> <key> — top-level string field.
payload_field() {
  printf '%s' "$1" | tr -d '\n' | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\(\([^\"\\\\]\|\\\\.\)*\)\".*/\1/p" | head -1
}

# payload_args <payload> — the toolArgs object, verbatim.
# Verified 2026-09-20: toolArgs is a nested JSON OBJECT, not an escaped string.
payload_args() { printf '%s' "$1" | tr -d '\n' | sed -n 's/.*"toolArgs"[[:space:]]*:[[:space:]]*{\(.*\)}.*/\1/p'; }

# arg_field <args> <key> — string field inside the tool arguments.
arg_field() {
  printf '%s' "$1" | tr -d '\n' | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\(\([^\"\\\\]\|\\\\.\)*\)\".*/\1/p" | head -1
}

repo_root() { git -C "$1" rev-parse --show-toplevel 2>/dev/null; }
has_workflow_config() { [ -f "$1/.ai/project/android-workflow.yml" ]; }
current_branch() { git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null; }

# cfg_list <config file> <key> — inline (key: [a, b]) or block (key:\n  - a) list.
cfg_list() {
  local f="$1" k="$2"
  sed -n "s/^$k:[[:space:]]*\[\(.*\)\].*/\1/p" "$f" | tr ',' '\n' | sed 's/[][ "]//g' | grep -v '^$'
  sed -n "/^$k:[[:space:]]*$/,/^[^[:space:]-]/{s/^[[:space:]]*-[[:space:]]*//p;}" "$f" | sed 's/["]//g' | grep -v '^$'
}
SH
```

- [ ] **Step 6: Write the hook**

```bash
cat > hooks/guard-rails.sh <<'SH'
#!/usr/bin/env bash
# preToolUse: the four rails. Inert outside repos configured for this workflow.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib.sh"

payload="$(cat)"
cwd="$(payload_field "$payload" cwd)"; [ -n "$cwd" ] || cwd="$PWD"
tool="$(payload_field "$payload" toolName)"
args="$(payload_args "$payload")"
cmd="$(arg_field "$args" command)"
path="$(arg_field "$args" path)"; [ -n "$path" ] || path="$(arg_field "$args" file_path)"

root="$(repo_root "$cwd")" || allow
[ -n "$root" ] || allow
has_workflow_config "$root" || allow
cfg="$root/.ai/project/android-workflow.yml"

# Fail closed for git commands that write, open otherwise.
writes_git=0
case "$cmd" in *"git push"*|*"git commit"*|*"git add"*|*"git reset"*) writes_git=1 ;; esac
on_error() { [ "$writes_git" -eq 1 ] && deny "guard-rails hook failed; blocking this git command. Run tests/run.sh."; allow; }
trap on_error ERR

protected="$(cfg_list "$cfg" protected_branches)"
[ -n "$protected" ] || protected="$(printf 'develop\nmain\nmaster\n')"
branch="$(current_branch "$root")"

is_protected() { printf '%s\n' "$protected" | grep -qx -- "$1"; }

if [ -n "$cmd" ]; then
  case "$cmd" in
    *"git push"*)
      case "$cmd" in
        *" -f"*|*"--force"*|*"origin +"*|*" +refs/"*)
          deny "Blocked: force-push. Rewriting a pushed branch is not allowed by this workflow." ;;
      esac
      target="$(printf '%s' "$cmd" | sed -n 's/.*git push[^|;]*[[:space:]]\([A-Za-z0-9._/-]*\)[[:space:]]*$/\1/p')"
      if [ -n "$target" ] && is_protected "$target"; then
        deny "Blocked: '$target' is protected. Push your working branch instead (feature/<KEY> or bugfix/<name>)."
      fi
      if [ -z "$target" ] && [ -n "$branch" ] && is_protected "$branch"; then
        deny "Blocked: HEAD is on protected branch '$branch'. Switch to a working branch first."
      fi ;;
    *"git commit"*)
      if [ -n "$branch" ] && is_protected "$branch"; then
        deny "Blocked: HEAD is on protected branch '$branch'. Commit on feature/<KEY> or bugfix/<name>."
      fi ;;
    *"git add"*)
      staged="$(printf '%s' "$cmd" | sed 's/.*git add//')"
      case "$staged" in
        *" -A"*|*" ."*|*" --all"*)
          hits="$(git -C "$root" status --porcelain 2>/dev/null | awk '{print $NF}' \
                  | grep -Ei '\.(jks|keystore|p12|pem)$|credentials.*\.json$|^local\.properties$|^keystore\.properties$' || true)"
          [ -n "$hits" ] && deny "Blocked: a secret file has uncommitted changes and would be staged: $(printf '%s' "$hits" | tr '\n' ' '). Stage files explicitly." ;;
        *)
          case "$staged" in
            *.jks*|*.keystore*|*.p12*|*.pem*|*credentials*.json*|*local.properties*|*keystore.properties*)
              deny "Blocked: that path looks like a secret or keystore. This workflow never commits credentials." ;;
          esac ;;
      esac ;;
  esac
  case "$cmd" in
    *versionCode*)
      case "$cmd" in
        *"sed -i"*|*"perl -pi"*|*">"*|*"tee "*)
          deny "Blocked: versionCode is owned by CI and release, never by this workflow." ;;
      esac ;;
  esac
fi

# File edits: versionCode inside a Gradle file.
case "$tool" in
  edit|create|str_replace_editor|apply_patch)
    case "$path" in
      *.gradle|*.gradle.kts)
        case "$args" in
          *versionCode*) deny "Blocked: versionCode is owned by CI and release, never by this workflow." ;;
        esac ;;
    esac ;;
esac

allow
SH
chmod +x hooks/guard-rails.sh
```

- [ ] **Step 7: Run the suite until it passes**

Run: `./tests/run.sh`
Expected: `17 passed, 0 failed`. Fix the hook, not the expectations. The most likely failures are the push-target regex (cases `push-no-target-on-develop`, `push-feature-branch`) and `git add .` detection.

- [ ] **Step 8: Register the hook**

```bash
mkdir -p com.github.copilot/hooks
cat > com.github.copilot/hooks/hooks.json <<'JSON'
{
  "hooks": {
    "preToolUse": [
      { "type": "command", "bash": "./hooks/guard-rails.sh", "timeoutSec": 10 }
    ]
  }
}
JSON
```

- [ ] **Step 9: Verify it fires through Copilot, not just the tests**

```bash
dir="$(./tests/fixtures/new-repo.sh on-feature)"
cd "$dir" && git remote add origin https://example.invalid/x.git
copilot -p "Run: git push origin develop" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools --no-ask-user
```
Expected: refused, quoting "protected". Then `rm -rf "$dir"`.

- [ ] **Step 10: Commit**

```bash
cd /Users/ericcerio/Projects/Eplayment/ai-workflow
git add hooks com.github.copilot tests
git commit -m "feat: guard-rails preToolUse hook with fixture-driven tests"
```

---

### Task 4: The post-edit hook

**Files:**
- Create: `hooks/post-edit.sh`
- Modify: `com.github.copilot/hooks/hooks.json`
- Create: `tests/cases/post-edit-runs-check.case`, `tests/cases/post-edit-no-checks.case`

**Interfaces:**
- Consumes: `hooks/lib.sh` from Task 3, and the `with-post-edit-check` fixture variant.
- Produces: the config key `lint.post_edit_checks` (a list of script paths, relative to the repo root), each called as `<script> <edited-file-path>`.

- [ ] **Step 1: Add the two cases**

```bash
cat > tests/cases/post-edit-runs-check.case <<'CASE'
# expect: allow
# match: post-edit-check-ran
# fixture: with-post-edit-check
# hook: post-edit.sh
{"sessionId":"s","timestamp":0,"cwd":"$FIXTURE","toolName":"edit","toolArgs":{"path":"$FIXTURE/app/src/main/java/ui/Screen.kt"}}
CASE

cat > tests/cases/post-edit-no-checks.case <<'CASE'
# expect: allow
# fixture: on-feature
# hook: post-edit.sh
{"sessionId":"s","timestamp":0,"cwd":"$FIXTURE","toolName":"edit","toolArgs":{"path":"$FIXTURE/app/build.gradle"}}
CASE
```

- [ ] **Step 2: Run to watch them fail**

Run: `./tests/run.sh`
Expected: both new cases fail (no `hooks/post-edit.sh`).

- [ ] **Step 3: Write the hook**

```bash
cat > hooks/post-edit.sh <<'SH'
#!/usr/bin/env bash
# postToolUse: run this repo's own checks against the edited file. Advisory only.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/lib.sh"

payload="$(cat)"
cwd="$(payload_field "$payload" cwd)"; [ -n "$cwd" ] || cwd="$PWD"
tool="$(payload_field "$payload" toolName)"
case "$tool" in edit|create|str_replace_editor|apply_patch) ;; *) allow ;; esac

args="$(payload_args "$payload")"
file="$(arg_field "$args" path)"; [ -n "$file" ] || file="$(arg_field "$args" file_path)"
[ -n "$file" ] || allow

root="$(repo_root "$cwd")" || allow
[ -n "$root" ] || allow
has_workflow_config "$root" || allow

out=""
while IFS= read -r check; do
  [ -n "$check" ] || continue
  [ -x "$root/$check" ] || continue
  result="$("$root/$check" "$file" 2>&1)" || true
  [ -n "$result" ] && out="$out$result
"
done <<EOF
$(cfg_list "$root/.ai/project/android-workflow.yml" "  post_edit_checks")
EOF

[ -n "$out" ] && printf '{"additionalContext":"%s"}\n' "$(printf '%s' "$out" | sed 's/"/\\"/g' | tr '\n' ' ')"
exit 0
SH
chmod +x hooks/post-edit.sh
```

- [ ] **Step 4: Run to verify both pass**

Run: `./tests/run.sh`
Expected: `19 passed, 0 failed`.

- [ ] **Step 5: Register it**

Add to `com.github.copilot/hooks/hooks.json` alongside `preToolUse`:

```json
"postToolUse": [ { "type": "command", "bash": "./hooks/post-edit.sh", "timeoutSec": 30 } ]
```

- [ ] **Step 6: Commit**

```bash
git add hooks com.github.copilot tests
git commit -m "feat: post-edit hook running repo-local checks"
```

---

### Task 5: The shared contracts

The two documents every stage skill reads. Nothing runs yet; this is what stops the same rules being restated thirteen times.

**Files:**
- Create: `shared/config.md`, `shared/ticket-file.md`

**Interfaces:**
- Produces: the config key names and the ticket-file field names used by every later task. Copy them verbatim from spec §7 and §6.

- [ ] **Step 1: Write `shared/config.md`**

Contents: the full `.ai/project/android-workflow.yml` example from spec §7 (all keys, with the comments); the rule that a missing config stops the run with "run `/android-onboard`"; the JDK resolution order; the `workflow_version` drift rule (print one line suggesting `copilot plugin update`, never block); and the statement that unknown keys are ignored and missing keys take their documented default.

- [ ] **Step 2: Write `shared/ticket-file.md`**

Contents: the path (`<git-common-dir>/android-workflow/<KEY>.md` via `git rev-parse --git-common-dir`, or the Task 1 fallback), the YAML header example from spec §6, the table of which skill writes which field, how the ticket key is resolved (argument → branch name → ask), and the diff-fingerprint rule: the fingerprint covers the tracked diff against the merge base plus staged and untracked files; `android-commit-push` recomputes it, and a mismatch expires both the security pass and any waivers.

- [ ] **Step 3: Verify the lint still passes and references resolve**

Run: `./tests/lint-skills.sh`
Expected: `skill lint: OK` (the dist-note skill's `../../shared/config.md` reference now resolves).

- [ ] **Step 4: Commit**

```bash
git add shared
git commit -m "docs: shared config and ticket-file contracts for the stage skills"
```

---

### Task 6: `/android-onboard`

**Files:**
- Create: `skills/android-onboard/SKILL.md`, `skills/android-onboard/reference.md`

**Interfaces:**
- Consumes: `shared/config.md`.
- Produces: `.ai/project/android-workflow.yml` in a target repo — the file every other skill reads.

- [ ] **Step 1: Write the detection rules into `reference.md`**

One section per config key, each naming the command that detects it:

| Key | Detection |
|---|---|
| `build.gradle_file` | first of `app/build.gradle`, `app/build.gradle.kts` that exists |
| `build.lint_task` / `build.test_task` | build types in the Gradle file: a `debug` block gives `lintDebug` / `testDebugUnitTest`; otherwise ask |
| `build.ktlint` | `grep -rl ktlint --include='*.gradle*'` → `gradle`; else `command -v ktlint` → `cli`; else `none` |
| `versioning.rule` | `git log -p --all -- <gradle_file> \| grep '^[+-].*versionName'` — a branch-name suffix on feature branches means `branch-suffix`, a patch bump means `patch-bump` |
| `release_notes.file` | `git ls-files \| grep -i release_note` |
| `release_notes.mode` | `git log -p -- <file>` — appended lines only means `append`; replaced lines means `replace` |
| `distribution.register_branch_in` | workflows whose `push.branches` lists anything besides the base branch |
| `security.known_tracked_secrets` | `git ls-files \| grep -Ei '\.(jks\|keystore\|p12\|pem)$\|credentials.*\.json$'` |
| `app_tag` | ask; suggest the app module's `applicationId` last segment, uppercased |
| `jira_base`, `base_branch`, `protected_branches` | defaults `https://eplayment.atlassian.net/browse/`, `develop`, `[develop, main, master]` |

- [ ] **Step 2: Write the skill**

```markdown
---
name: android-onboard
description: Set up an Android repository for the Copilot Android workflow by detecting its build, versioning, release-notes and distribution conventions and writing .ai/project/android-workflow.yml. Use when a repo has no workflow config, when /ticket says to run onboarding, or when adopting the workflow in a new Android project.
---

# Onboard a repository — the Android workflow

Read `../../shared/config.md`, then `reference.md` in this folder.

1. **AICS check.** No `.ai/` directory → say that `epm aics install` must run first, offer to run it, and **wait for a yes**. Never run it unasked.
2. **Detect** every key using the table in `reference.md`. Note which values you inferred and which you could not.
3. **Draft the architecture docs.** If `.ai/project/architecture.md` or `conventions.md` are missing, write drafts from the code: the layering actually used (`ViewModel → UseCase → Repository → Api` or otherwise), MVVM vs MVI per area, the design-system widgets, and the error-handling convention. Mark them `> Draft, written by /android-onboard — review before relying on it.`
4. **Ask** about anything you could not settle, one question at a time. `app_tag` always gets confirmed.
5. **Write** `.ai/project/android-workflow.yml`, including `workflow_version` from the installed plugin's `plugin.json`.
6. **Show** what you wrote (`git status --short` and the config) and **do not commit**.
7. **Report legacy files** that can now be deleted: `.github/prompts/*.prompt.md` that reference `.ai/department/` modules, and symlinks under `.claude/` whose target is missing.
```

- [ ] **Step 3: Lint**

Run: `./tests/lint-skills.sh`
Expected: `skill lint: OK`.

- [ ] **Step 4: Run it against a throwaway clone of PIXEL**

```bash
git clone -q /Users/ericcerio/Projects/Eplayment/eplayment-pixel-android /tmp/pixel-onboard-test
cd /tmp/pixel-onboard-test
copilot -p "/android-onboard" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools
cat .ai/project/android-workflow.yml
```
Expected, per spec §7: `gradle_file: app/build.gradle`, `lint_task: lintDebug`, `test_task: testDebugUnitTest`, `ktlint: none`, `versioning.rule: patch-bump`, `release_notes.file: FirebaseAppDistributionConfig/release_notes.txt`, `release_notes.mode: append`, and `known_tracked_secrets` listing the tracked `fastlane/firebase_credentials.json` path. It must also report the two broken prompt files. Fix `reference.md` until the detection produces this, then `rm -rf /tmp/pixel-onboard-test`.

- [ ] **Step 5: Commit**

```bash
git add skills/android-onboard
git commit -m "feat: android-onboard writes a repo's workflow config"
```

---

### Task 7: `/android-lint` — stage 05

**Files:**
- Create: `skills/android-lint/SKILL.md`, `skills/android-lint/reference.md`

**Interfaces:**
- Consumes: `shared/config.md` (`build.ktlint`, `build.lint_task`, `build.jdk`, `base_branch`).
- Produces: skill `android-lint`; writes nothing to the ticket file.

- [ ] **Step 1: Recover the module**

```bash
mkdir -p skills/android-lint
git -C /Users/ericcerio/Projects/Eplayment/eplayment-pixel-android show \
  6f6cfff7^:.github/pixel-workflows/lint.md > skills/android-lint/reference.md
```

- [ ] **Step 2: De-repo it**

Edit `reference.md`: delete both `export JAVA_HOME=/Users/robcastro/...` lines and point at the JDK resolution in `shared/config.md`; replace `./gradlew lintDebug` with `./gradlew <build.lint_task>`; replace "the repo does not ship a ktlint setup today" with the three `build.ktlint` values (`gradle` → run `ktlintFormat ktlintCheck`; `cli` → run the `ktlint` binary on changed files; `none` → apply the rules by hand and say so in the summary). Keep the sanitation checklist as it is.

- [ ] **Step 3: Write the skill**

```markdown
---
name: android-lint
description: Format and lint the Kotlin changes on this branch with ktlint, Android lint, and the code-sanitation checklist, on changed files only. Use when the user asks to lint, format, clean up or sanitise their Android changes, or as stage 05 of the Android workflow.
---

# Lint and sanitation — stage 05

Read `../../shared/config.md`, then `reference.md` in this folder.

1. Resolve the changed Kotlin files: `git diff --name-only $(git merge-base HEAD <base_branch>) -- '*.kt' '*.kts'`, plus staged and untracked ones. No changes → say so and stop.
2. ktlint, according to `build.ktlint`.
3. `./gradlew <build.lint_task>` with the resolved JDK. Report failures with `file:line`.
4. The sanitation checklist from `reference.md`, on the changed files only.
5. Re-stage anything reformatted that was already staged.
6. Print what ran, what was skipped and why. When `build.ktlint` is `none`, recommend adding `org.jlleitschuh.gradle.ktlint`.

Fix only what this diff caused. Never reformat the whole tree.
```

- [ ] **Step 4: Lint and smoke-test**

```bash
./tests/lint-skills.sh
# a fresh clone with the Task 6 config committed and a one-line .kt change:
cd /tmp/pixel-lint-test
copilot -p "/android-lint" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools
```
Expected: it lists only the changed file, reports that ktlint is not wired in, and runs `lintDebug`.

- [ ] **Step 5: Commit**

```bash
git add skills/android-lint
git commit -m "feat: android-lint skill (stage 05)"
```

---

### Task 8: `/android-release-notes` — stage 06

**Files:**
- Create: `skills/android-release-notes/SKILL.md`, `skills/android-release-notes/reference.md`

**Interfaces:**
- Consumes: `versioning.rule`, `release_notes.{file,mode}`, `jira_base`, `distribution.register_branch_in`, `build.gradle_file`.
- Produces: skill `android-release-notes`; writes nothing to the ticket file.

- [ ] **Step 1: Recover the module**

```bash
mkdir -p skills/android-release-notes
git -C /Users/ericcerio/Projects/Eplayment/eplayment-pixel-android show \
  6f6cfff7^:.github/pixel-workflows/versioning.md > skills/android-release-notes/reference.md
```

- [ ] **Step 2: Add the second versioning rule**

That module only knows patch-bumping. `reference.md` must document both:
- `patch-bump`: `versionName "3.4.27"` → `"3.4.28"`; the release-notes line is appended if absent.
- `branch-suffix`: `versionName "2.13.9"` → `"2.13.9-<branch-topic>"`, where `<branch-topic>` is the branch name after its prefix with `/` → `-`; applied once and never stacked (`2.13.9-a-b` is a bug); with `mode: replace` the release-notes file is replaced with this branch's ticket URL.
- Both: `versionCode` is never touched, and the guard-rails hook denies it anyway.

- [ ] **Step 3: Write the skill**

```markdown
---
name: android-release-notes
description: Update the Android release notes and versionName for the current ticket, and register the branch for distribution if the repo needs it. Use when the user asks to bump the version, add the ticket to release notes, or prepare a branch for distribution, or as stage 06 of the Android workflow.
---

# Release notes and version — stage 06

Read `../../shared/config.md` and `../../shared/ticket-file.md`, then `reference.md` here.

1. Resolve the ticket key: argument → branch name → ask.
2. Apply `versioning.rule` to `versionName` in `build.gradle_file`. **Never touch `versionCode`.**
3. Apply `release_notes.mode` to `release_notes.file` with `<jira_base><KEY>`: `append` skips exact duplicates; `replace` writes this branch's ticket(s) only.
4. If `distribution.register_branch_in` names a workflow, add the current branch to its `push.branches` list if absent, preserving formatting.
5. Print a diff summary of every file you changed. Stage nothing.
```

- [ ] **Step 4: Verify both rules on throwaway clones**

```bash
# patch-bump repo
cd /tmp/pixel-notes-test && git checkout -b feature/TA-9999
copilot -p "/android-release-notes TA-9999" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools
git diff --stat   # app/build.gradle + release_notes.txt, versionCode unchanged
```
Then repeat in a clone of the branch-suffix repo (config written by `/android-onboard` first) on `feature/TA-9999`, expecting a suffixed `versionName`, a replaced release-notes line, and the branch added to the workflow's `push.branches`.

- [ ] **Step 5: Commit**

```bash
git add skills/android-release-notes
git commit -m "feat: android-release-notes skill (stage 06)"
```

---

### Task 9: `/android-test` — stage 07

**Files:**
- Create: `skills/android-test/SKILL.md`, `skills/android-test/reference.md`

**Interfaces:**
- Consumes: `build.test_task`, `build.jdk`.
- Produces: skill `android-test`; accepts an optional scope argument (feature word, package fragment, class name) and `--all`.

- [ ] **Step 1: Write `reference.md`**

Contents: scope resolution (match the scope case-insensitively against test class names and the package path under `src/test`; list matches before running; no match → show the nearest three and stop); the Gradle invocation `./gradlew <test_task> --tests '*<Scope>*'`; no scope → tests related to changed files, found by matching changed class names against test class names; the fake-driven test style for writing tests (`UnconfinedTestDispatcher`, `runTest`, fake use cases, one behaviour per test, no Robolectric); and the rule that a pass is only ever reported with the command output.

- [ ] **Step 2: Write the skill**

```markdown
---
name: android-test
description: Run or write Android JVM unit tests for a feature, package, class, or the current changes, using the repo's Gradle test task and the right JDK. Use when the user asks to run tests, test a feature, check whether tests pass, or add unit tests, or as stage 07 of the Android workflow.
---

# Unit tests — stage 07

Read `../../shared/config.md` and `../../shared/ticket-file.md`, then `reference.md` here.

1. Resolve the scope: the argument, else the changed files, else ask. `--all` runs everything.
2. List what matched before running anything.
3. Run `./gradlew <build.test_task> --tests '<pattern>'` with the resolved JDK.
4. Report the real result, quoting the command output. **Never claim a pass you did not see.**
5. Writing tests: only in a feature chain, or when asked. Follow the style in `reference.md`. A bugfix chain runs the existing tests; a cheap regression test is welcome, not required.
6. On failure, report each failing test with its assertion message and `file:line`. Do not "fix" a test by weakening its assertion.
```

- [ ] **Step 3: Smoke-test against a repo with many test files**

```bash
cd /tmp/pixel-test-test
copilot -p "/android-test subscriptions" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools
```
Expected: it lists the matched classes (in PIXEL, the ones under `domain/model/iap` such as `SubscriptionTierActionTest` and `CancelTierSubscriptionTest`), runs a filtered `testDebugUnitTest`, and quotes the output. Also check `/android-test zzzznope` reports no match and does **not** run the suite.

- [ ] **Step 4: Commit**

```bash
git add skills/android-test
git commit -m "feat: android-test skill (stage 07)"
```

---

### Task 10: `/android-security-gate` — stage 08, gate 2

**Files:**
- Create: `skills/android-security-gate/SKILL.md`, `skills/android-security-gate/reference.md`

**Interfaces:**
- Consumes: `security.{guarded_files,known_tracked_secrets}`, `base_branch`, `shared/ticket-file.md`.
- Produces: the ticket file's `security:` block — `result` (`pass`/`fail`/`waived`), `diff` (fingerprint), `waivers[]` (`finding`, `reason`). `android-commit-push` reads these.

- [ ] **Step 1: Recover the module**

```bash
mkdir -p skills/android-security-gate
git -C /Users/ericcerio/Projects/Eplayment/eplayment-pixel-android show \
  6f6cfff7^:.github/pixel-workflows/security.md > skills/android-security-gate/reference.md
```

- [ ] **Step 2: De-repo it and write layer 4**

Edit `reference.md`: replace the hardcoded guarded-file list with `security.guarded_files` from config (keeping the PIXEL list as a worked example), fix the typo "explicihahatly", and rewrite layer 4 as: use the CLI's built-in `/security-review` when the surface offers it; otherwise work through the checklist below. Write that checklist out — one line per item in layers 2 and 3, phrased as a question, with what a finding looks like.

- [ ] **Step 3: Write the skill**

```markdown
---
name: android-security-gate
description: Run the four-layer Android security review on the current changes - guarded files, a diff scan for secrets and PII and permission or dependency changes, a hardening audit, and a security review - and block the push on high-severity findings. Use when the user asks to check security, review a diff for vulnerabilities, or before pushing, or as stage 08 of the Android workflow.
---

# Security gate — stage 08 (gate 2)

Read `../../shared/config.md` and `../../shared/ticket-file.md`, then `reference.md` here.

1. Collect the changes: `git diff $(git merge-base HEAD <base_branch>)`, plus staged and untracked files. Nothing to review → say so and stop.
2. Compute the diff fingerprint as `shared/ticket-file.md` defines it.
3. Run all four layers from `reference.md`. Files listed in `security.known_tracked_secrets` are reported once as pre-existing open issues, never as findings against this diff.
4. Present findings grouped by severity, each with `file:line` and the fix.
5. **Gate 2.** No high-severity findings → record `result: pass` with the fingerprint. High-severity findings → the push is blocked. The developer may fix them, or waive one by giving a written reason; record each waiver under `waivers:` with its finding, and set `result: waived`. Never invent a waiver reason, and never waive on your own initiative.
6. Print the summary that `android-commit-push` will repeat to the reviewer.
```

- [ ] **Step 4: Verify it blocks, on a deliberately bad diff**

Generate the offending literal at run time — never commit one to this repo:

```bash
cd /tmp/pixel-sec-test && git checkout -b feature/TA-9998
printf 'const val %s = "sk-live-%s"\n' "DEMO_CREDENTIAL" "$(openssl rand -hex 5)" \
  >> app/src/main/java/com/epcorp/pixel/Debug.kt
copilot -p "/android-security-gate" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools --no-ask-user
grep -A4 '^security:' "$(git rev-parse --git-common-dir)/android-workflow/TA-9998.md"
```
Expected: a high-severity hardcoded-secret finding, `result: fail` (with `--no-ask-user` it cannot obtain a waiver), and no `pass` recorded.

- [ ] **Step 5: Verify it passes on a clean diff**

Revert that line (`git checkout -- app/src/main/java/com/epcorp/pixel/Debug.kt`), change a string resource instead, rerun, and expect `result: pass` with a fingerprint.

- [ ] **Step 6: Commit**

```bash
git add skills/android-security-gate
git commit -m "feat: android-security-gate skill (stage 08, gate 2)"
```

---

### Task 11: `/android-commit-push` — stage 09, gate 3

**Files:**
- Create: `skills/android-commit-push/SKILL.md`, `skills/android-commit-push/reference.md`

**Interfaces:**
- Consumes: the ticket file's `security:` block and `name`/`key`; `protected_branches`; `distribution.open_draft_pr`; the Task 1 finding `DRAFT_PR_WITHOUT_GH`.
- Produces: the ticket file's `pushed:` field.

- [ ] **Step 1: Write `reference.md`**

Contents: the commit message format `<KEY>: <name>` with no attribution trailers; the pre-flight list (HEAD not protected; fingerprint matches a recorded pass; nothing staged yet); what the confirmation shows (message, file list, `<branch> → <remote>`); the rule that one confirmation covers stage, commit and push; and the draft-PR behaviour settled by check 6 — `gh pr create --base <base_branch> --head <branch> --draft --fill`, which needs a working GitHub credential. If `gh` is missing or its auth fails (an invalid `GITHUB_TOKEN` in the environment overrides the keyring and breaks it), fall back to printing the compare URL `<remote-web-url>/compare/<base>...<branch>?expand=1&draft=1`.

- [ ] **Step 2: Write the skill**

```markdown
---
name: android-commit-push
description: Commit and push the current Android ticket's work after showing the exact commit message, file list and push target, then offer the draft pull request. Use when the user asks to commit and push their ticket, or as stage 09 of the Android workflow. Requires a passing security gate for the current changes.
---

# Commit and push — stage 09 (gate 3)

Read `../../shared/config.md` and `../../shared/ticket-file.md`, then `reference.md` here.

1. **Refuse on a protected branch.** HEAD in `protected_branches` → stop and point at `/android-branch`.
2. **Security.** Recompute the diff fingerprint. No recorded `pass`/`waived` for it → run the `android-security-gate` skill now and continue only if it clears.
3. **Resolve the message** `<KEY>: <name>` from the ticket file; ask for the name if it is missing.
4. **Gate 3.** Show the message, the files that would be committed, and `<branch> → <remote>`, then **stop and wait**. Nothing is staged before the answer. One yes covers stage, commit and push.
5. Stage exactly those files, commit (no `Co-Authored-By` or other trailers), push the branch. **Never force-push.**
6. Record `pushed: <sha>`.
7. **Draft PR.** With `distribution.open_draft_pr: true`, offer it, then run `gh pr create --base <base_branch> --head <branch> --draft --fill`. If `gh` is missing or unauthenticated, say so and hand over the compare URL instead. Repeat any security waivers in the summary so the reviewer sees them.
8. Never run Fastlane.
```

- [ ] **Step 3: Verify the gate holds without a security pass**

```bash
cd /tmp/pixel-push-test && git checkout -b feature/TA-9997 && printf '// touch\n' >> app/build.gradle
copilot -p "/android-commit-push" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools --no-ask-user
git log --oneline -1 && git status --porcelain
```
Expected: no new commit and nothing staged — it ran the security gate and then had no way to ask for confirmation.

- [ ] **Step 4: Verify the protected-branch refusal**

```bash
git checkout -- app/build.gradle && git checkout develop
copilot -p "/android-commit-push" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools --no-ask-user
```
Expected: refuses, naming `/android-branch`. The hook is the backstop, but the skill must refuse on its own.

- [ ] **Step 5: Commit**

```bash
git add skills/android-commit-push
git commit -m "feat: android-commit-push skill (stage 09, gate 3)"
```

---

### Task 12: `/android-plan` — stages 01+02, gate 1

**Files:**
- Create: `skills/android-plan/SKILL.md`, `skills/android-plan/reference.md`

**Interfaces:**
- Consumes: `shared/ticket-file.md`, and the target repo's `.ai/project/architecture.md` and `conventions.md`.
- Produces: the ticket file's `key`, `name`, `type`, `architecture`, `plan_approved`, and the `## Acceptance criteria` and `## Approved plan` sections that `android-develop` reads.

- [ ] **Step 1: Recover the probes**

```bash
mkdir -p skills/android-plan
git -C /Users/ericcerio/Projects/Eplayment/eplayment-pixel-android show \
  6f6cfff7^:.github/pixel-workflows/context-awareness.md > skills/android-plan/reference.md
```

- [ ] **Step 2: Add intake and the plan shape to `reference.md`**

The intake fields and their validation (`<LETTERS>-<DIGITS>` for the key); that the UI reference is asked once and never blocks; and what the presented plan contains for each type — feature: code to reuse, the MVVM/MVI default with the evidence for it, git and ticket warnings, the new files; fix: suspected cause, files to change, the smallest fix, the same warnings.

- [ ] **Step 3: Write the skill**

```markdown
---
name: android-plan
description: Plan an Android feature or bugfix before any code is written - collect the ticket details, find what to reuse, detect the architecture pattern and git state, then present the plan for approval. Use when the user wants to plan a ticket or a fix, investigate what a change would touch, or as stages 01-02 of the Android workflow.
---

# Plan — stages 01+02 (gate 1)

Read `../../shared/config.md` and `../../shared/ticket-file.md`, then `reference.md` here.

Usage: `/android-plan <KEY> [feature|fix]`. Missing type → ask.

1. **Intake**, one question at a time for anything missing: name; key (validated `<LETTERS>-<DIGITS>`); acceptance criteria for a feature, or observed vs expected for a fix. A required field still missing → **stop**. Then ask **once** for a UI reference (feature) or repro steps (fix); "skip" is accepted and never blocks.
2. **Probes** from `reference.md`: code to reuse; the pattern already used in the area (MVVM or MVI — features only, a fix follows what is there); git and ticket state (dirty tree, an existing branch for this key, the key already in the release notes).
3. **Present the plan.** Say plainly what already exists and should be reused rather than rewritten.
4. **Gate 1.** Ask for approval of the plan and, for a feature, the architecture choice. **Wait for an explicit go.** Record the ticket fields and the plan immediately; record `plan_approved` only after the go.
5. Print what to run next: `/android-branch`, or `/ticket <KEY>` to continue the whole workflow.

Write no code in this skill. That is `/android-develop`.
```

- [ ] **Step 4: Verify the gate holds and nothing is written**

```bash
cd /tmp/pixel-plan-test
copilot -p "/android-plan TA-9996 fix — observed: avatar missing on own profile; expected: avatar shown" \
  --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools --no-ask-user
git status --porcelain && git branch --show-current
cat "$(git rev-parse --git-common-dir)/android-workflow/TA-9996.md"
```
Expected: no files changed, no branch created, the ticket file has the fields and the plan but **no** `plan_approved`.

- [ ] **Step 5: Commit**

```bash
git add skills/android-plan
git commit -m "feat: android-plan skill (stages 01-02, gate 1)"
```

---

### Task 13: `/android-branch` — stage 03

**Files:**
- Create: `skills/android-branch/SKILL.md`, `skills/android-branch/reference.md`

**Interfaces:**
- Consumes: ticket file `key`/`type`; `base_branch`, `protected_branches`, `bugfix_branch_rule`.
- Produces: the ticket file's `branch` field.

- [ ] **Step 1: Recover the module**

```bash
mkdir -p skills/android-branch
git -C /Users/ericcerio/Projects/Eplayment/eplayment-pixel-android show \
  6f6cfff7^:.github/pixel-workflows/branching.md > skills/android-branch/reference.md
```

- [ ] **Step 2: Add the bugfix rule variants**

Add to `reference.md`: `ask` (default) — stay on the current `bugfix/*` branch, else ask, offering the newest `bugfix/*` on the remote (`git for-each-ref --sort=-committerdate --count=1 --format='%(refname:short)' refs/remotes/origin/bugfix`) and `bugfix/<KEY>`; `batch` — never ask, use the newest batch branch; `per-ticket` — always `bugfix/<KEY>`. Note that both conventions are live today (`bugfix/TA-1060` and `bugfix/antimony`), which is why `ask` is the default.

- [ ] **Step 3: Write the skill**

```markdown
---
name: android-branch
description: Create or pick the right git branch for an Android ticket - reusing the current branch, stacking on an epic branch, or cutting a new feature or bugfix branch from the base branch. Use when the user asks which branch to work on or to start a branch for a ticket, or as stage 03 of the Android workflow.
---

# Branch — stage 03

Read `../../shared/config.md` and `../../shared/ticket-file.md`, then `reference.md` here.

1. Resolve the key and type from the ticket file, the argument, or by asking.
2. **Feature:** current branch name contains the key → stay. On an epic branch `feature/<topic>` where `<topic>` is not a ticket key → `git checkout -b <topic>/<KEY>` **without** checking out the base branch. Otherwise `git checkout <base_branch> && git checkout -b feature/<KEY>`.
3. **Bugfix:** follow `bugfix_branch_rule`.
4. **Dirty tree:** show it and let the developer decide before switching. Never stash silently.
5. Never commit on a protected branch, and never create a branch while HEAD is detached.
6. Record `branch:` and print it.
```

- [ ] **Step 4: Verify all three feature paths**

```bash
cd /tmp/pixel-branch-test
git checkout -q -b feature/subscriptions   # epic branch
copilot -p "/android-branch TA-9995" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools --no-ask-user
git branch --show-current   # expect: subscriptions/TA-9995
git checkout -q develop
copilot -p "/android-branch TA-9994" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools --no-ask-user
git branch --show-current   # expect: feature/TA-9994
copilot -p "/android-branch TA-9994" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools --no-ask-user
git branch --show-current   # expect: unchanged, feature/TA-9994
```

- [ ] **Step 5: Commit**

```bash
git add skills/android-branch
git commit -m "feat: android-branch skill (stage 03)"
```

---

### Task 14: `/android-develop` — stage 04

**Files:**
- Create: `skills/android-develop/SKILL.md`, `skills/android-develop/reference.md`

**Interfaces:**
- Consumes: the ticket file's approved plan and `architecture`; the target repo's `.ai/project/architecture.md`, `conventions.md`, `ui-reference.md`.
- Produces: skill `android-develop`, accepting `feature` or `fix` mode.

- [ ] **Step 1: Write `reference.md`**

Contents: the wiring order `ViewModel → UseCase(Imp) → Repository → Api` with route registration and DI binding; the rule that the repo's `architecture.md` owns the templates and this file never restates them; the Compose checker (run it after any `@Composable` is added or changed, and fix what it flags); and the fix-mode rules — smallest correct change, follow the touched area's existing pattern, no unrelated refactoring, no new scaffolding.

- [ ] **Step 2: Write the skill**

```markdown
---
name: android-develop
description: Implement an approved Android plan - scaffolding a feature through ViewModel, UseCase, Repository and Api with routes and DI, or making the smallest correct fix for a bug. Use when the user asks to implement a planned ticket or write the code for a fix, or as stage 04 of the Android workflow.
---

# Development — stage 04 (the developer's call)

Read `../../shared/config.md` and `../../shared/ticket-file.md`, then `reference.md` here.

1. **Require an approved plan.** No `plan_approved` in the ticket file → stop and send the developer to `/android-plan`. Never improvise the plan.
2. Re-read the approved plan and the repo's `.ai/project/architecture.md` and `conventions.md`.
3. **Feature:** reuse what the plan listed; scaffold only the new files it named, following the repo's templates and the recorded MVVM/MVI choice; register routes and bind DI. Build the UI from the UI reference when there is one, otherwise from the acceptance criteria; map onto the design system with no hardcoded styling, and flag every visual assumption.
4. **Fix:** the smallest correct change in the existing pattern. No refactoring beyond the fix.
5. Run the Compose checker after touching any `@Composable`.
6. Print the files you created and changed. Do not lint, test, commit or push here — those are stages 05 onward.
```

- [ ] **Step 3: Verify it refuses without a plan**

```bash
cd /tmp/pixel-dev-test && git checkout -b feature/TA-9993
copilot -p "/android-develop TA-9993" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools --no-ask-user
git status --porcelain
```
Expected: no files changed; it names `/android-plan`.

- [ ] **Step 4: Commit**

```bash
git add skills/android-develop
git commit -m "feat: android-develop skill (stage 04)"
```

---

### Task 15: The three chains

**Files:**
- Create: `skills/ticket/SKILL.md`, `skills/bugfix/SKILL.md`, `skills/android-ship/SKILL.md`

**Interfaces:**
- Consumes: every stage skill from Tasks 6–14, and the Task 1 finding `SKILL_CALLS_SKILL`.
- Produces: `/ticket`, `/bugfix`, `/android-ship`.

- [ ] **Step 1: Write `/android-ship`**

```markdown
---
name: android-ship
description: Run the finishing half of the Android workflow on the current branch - lint, release notes and version, tests, the security gate, commit and push, then the distribution note. Use when the user has written code by hand and wants it shipped, or as stages 05-10 of the Android workflow.
---

# Ship — stages 05→10

Read `../../shared/ticket-file.md`. Resolve the ticket key: argument → branch name → ask.

Run these in order, stopping at the first failure and saying which stage stopped it:

1. `android-lint`
2. `android-release-notes`
3. `android-test`
4. `android-security-gate` — gate 2; a block stops the chain here
5. `android-commit-push` — gate 3; nothing is staged before the developer's yes
6. `android-dist-note`

Never skip a stage. Never do a stage's work yourself: each is a skill and owns its own rules.
```

Check 3 passed on 2026-09-20 (a skill invoked a sibling skill, which ran to completion), so the chains invoke the stage skills directly. The read-by-path fallback is not needed.

- [ ] **Step 2: Write `/ticket`**

```markdown
---
name: ticket
description: Run the full Android feature workflow for a Jira ticket - intake and plan, branch, optional implementation, then lint, version, tests, security gate, commit and push, and the distribution note. Use when the user gives a Jira key to work on, says they want to start a ticket or feature, or types /ticket.
---

# /ticket — the feature workflow

Read `../../shared/ticket-file.md` first, and **resume**: if a ticket file already exists for this key, start at the first unfinished stage and say where you resumed.

1. `android-plan <KEY> feature` — gate 1, waits for the go.
2. `android-branch`
3. Ask **Y / N**: should the development skill write this?
   - **Y** → `android-develop`
   - **N** → stop here and print: *"Write the code, then run `/android-ship`."* N is a legitimate answer; do not argue with it.
4. `android-ship`

Stages 05–10 belong to `android-ship`; never inline them here.
```

- [ ] **Step 3: Write `/bugfix`**

Identical to `/ticket` except: the frontmatter description ("Run the full Android bugfix workflow … Use when the user reports a bug to fix, gives a Jira key for a defect, or types /bugfix"); step 1 is `android-plan <KEY> fix`; step 3's Y branch calls `android-develop` in fix mode; and it notes that fixes batch as separate commits on the bugfix branch, so a second fix on the same branch is normal.

- [ ] **Step 4: Verify the chain stops at gate 1**

```bash
cd /tmp/pixel-chain-test
copilot -p "/ticket TA-9992 — name: Cancel reason sheet; AC: user picks a reason before cancelling" \
  --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools --no-ask-user
git branch --show-current && git status --porcelain
```
Expected: it plans, then stops for approval — still on the original branch, nothing changed.

- [ ] **Step 5: Verify resume**

Run the same command again. Expected: it says it resumed from the existing ticket file rather than asking for the name and criteria again.

- [ ] **Step 6: Lint and commit**

```bash
./tests/lint-skills.sh
git add skills/ticket skills/bugfix skills/android-ship
git commit -m "feat: ticket, bugfix and ship chains over the stage skills"
```

---

### Task 16: Manual acceptance, then publish v0.1.0

**Files:**
- Create: `docs/checks/2026-09-20-acceptance.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above.
- Produces: the tag `v0.1.0` on `eplayment/ai-workflow`, installable with `copilot plugin install eplayment/ai-workflow`.

- [ ] **Step 1: Build the sandbox**

```bash
git clone -q /Users/ericcerio/Projects/Eplayment/eplayment-pixel-android /tmp/acceptance-pixel
cd /tmp/acceptance-pixel
git init -q --bare /tmp/acceptance-remote.git
git remote set-url origin /tmp/acceptance-remote.git   # nothing can reach the real remote
copilot -p "/android-onboard" --plugin-dir /Users/ericcerio/Projects/Eplayment/ai-workflow --allow-all-tools
```

- [ ] **Step 2: Run the five acceptance scenarios**

In an **interactive** session (the gates need real answers), in the CLI, and in Android Studio too if check 1 passed. Record the outcome of each in `docs/checks/2026-09-20-acceptance.md`:

1. `/android-plan TA-1234 fix` → plan only; no branch, no edits.
2. `/android-test subscriptions` → matched classes listed, filtered run, real output.
3. `/android-security-gate` → four layers reported on the current diff.
4. `/ticket TA-1234` end to end, answering **Y** at stage 04 → stops at all three gates, and the push reaches `/tmp/acceptance-remote.git` only after the confirmation.
5. `/ticket TA-1235` answering **N** → chain stops after branching; write a one-line change by hand; `/android-ship` finishes it.

- [ ] **Step 3: Verify the rails in a real session**

In the sandbox, ask Copilot for each of: `git push origin develop`, `git push -f`, bumping `versionCode`, and `git add .` while the tracked credentials file has uncommitted changes. All four must be refused with the hook's reason.

- [ ] **Step 4: Run both test suites and clean up**

```bash
cd /Users/ericcerio/Projects/Eplayment/ai-workflow && ./tests/run.sh && ./tests/lint-skills.sh
grep -rn "/Users/" skills/ shared/ || echo "no personal paths"
rm -rf /tmp/acceptance-pixel /tmp/acceptance-remote.git
```
Expected: `19 passed, 0 failed`, `skill lint: OK`, `no personal paths`.

- [ ] **Step 5: Publish**

```bash
git add docs/checks/2026-09-20-acceptance.md README.md
git commit -m "docs: acceptance run for v0.1.0"
# create the private repo eplayment/ai-workflow, then:
git remote add origin git@github.com:eplayment/ai-workflow.git
git push -u origin main
git tag -a v0.1.0 -m "Android Copilot workflow v0.1.0"
git push origin v0.1.0
```

- [ ] **Step 6: Verify a clean install**

```bash
copilot plugin install eplayment/ai-workflow
copilot skill list | grep -E 'ticket|android-'
```
Expected: all 13 skills listed, installed from the repo rather than `--plugin-dir`.

---

### Task 17: PIXEL pilot

**Files (in `/Users/ericcerio/Projects/Eplayment/eplayment-pixel-android`):**
- Create: `.ai/project/android-workflow.yml`
- Modify: `.claude/hooks/check-hardcoded-strings.sh`
- Delete: `.github/prompts/ticket.prompt.md`, `.github/prompts/bugfix.prompt.md`, `.claude/workflows/pixel`

**Interfaces:**
- Consumes: the published plugin.
- Produces: PIXEL's config, and the pattern the second repo follows.

- [ ] **Step 1: Branch and onboard**

```bash
cd /Users/ericcerio/Projects/Eplayment/eplayment-pixel-android
git checkout develop && git pull && git checkout -b feature/copilot-android-workflow
copilot -p "/android-onboard" --allow-all-tools
```

- [ ] **Step 2: Fill in what onboarding could not settle**

Check `.ai/project/android-workflow.yml` against spec §7: `app_tag: PIXEL`, `guarded_files` carrying the layer-1 list (`app/src/main/cpp/NativeGuards.cpp`, `**/ui/utils/security/ReverseEngineerUtils*`, `**/data/security/IntegrityService*`, `**/core/di/IntegrityModule*`, `app/build.gradle`), `known_tracked_secrets` listing the tracked credentials file, and `lint.post_edit_checks: [.claude/hooks/check-hardcoded-strings.sh]`.

- [ ] **Step 3: Make the hardcoded-strings script work for both agents**

In `.claude/hooks/check-hardcoded-strings.sh`, take the file path from `$1` and fall back to the old payload, so Claude Code keeps working:

```bash
file="${1:-}"
if [ -z "$file" ]; then
  payload=$(cat)
  file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')
fi
```

- [ ] **Step 4: Delete what the plugin replaces**

```bash
git rm .github/prompts/ticket.prompt.md .github/prompts/bugfix.prompt.md .claude/workflows/pixel
```

- [ ] **Step 5: Verify end to end on the real repo**

```bash
copilot -p "/android-test subscriptions" --allow-all-tools
copilot -p "/android-security-gate" --allow-all-tools
```
Expected: both run against PIXEL's real config with no `--plugin-dir`.

- [ ] **Step 6: Commit and open the PR**

```bash
git add .ai/project/android-workflow.yml .claude/hooks/check-hardcoded-strings.sh
git commit -m "feat: adopt the Copilot Android workflow plugin

Adds .ai/project/android-workflow.yml, makes the hardcoded-strings hook usable
by both Claude Code and Copilot, and removes the prompts and symlink that
pointed at the .ai/department modules lost to aics sync in 6f6cfff7."
git push -u origin feature/copilot-android-workflow
```

Then take one real ticket through `/ticket` and record anything that needed a human nudge.

---

### Task 18: eplayment-android pilot

**Files (in `/Users/ericcerio/Projects/Eplayment/eplayment-android`):**
- Create: `.ai/` (via `epm aics install`), `.ai/project/android-workflow.yml`, `.ai/project/architecture.md`, `.ai/project/conventions.md`

**Interfaces:**
- Consumes: the published plugin and Task 17's pattern.
- Produces: proof of portability — **no skill may be edited in this task**. If one must be, that is a defect: fix it in the plugin, tag a patch release, and note it.

- [ ] **Step 1: Branch and install AICS**

```bash
cd /Users/ericcerio/Projects/Eplayment/eplayment-android
git checkout develop && git pull && git checkout -b feature/copilot-android-workflow
epm aics install
```

- [ ] **Step 2: Onboard**

```bash
copilot -p "/android-onboard" --allow-all-tools
```
Expected, per spec §7: `versioning.rule: branch-suffix`, `release_notes.mode: replace`, `register_branch_in: .github/workflows/distribute-in-develop.yml`, and `known_tracked_secrets` listing both tracked keystore paths. Confirm `app_tag` when asked. Review the drafted `architecture.md` and `conventions.md` against the real `:app` and `:core` layout and correct them by hand.

- [ ] **Step 3: Verify the version rule on a scratch branch**

```bash
git checkout -b feature/TA-9991
copilot -p "/android-release-notes TA-9991" --allow-all-tools
git diff -- app/build.gradle FirebaseAppDistributionConfig .github/workflows
```
Expected: `versionName "2.13.10-TA-9991"`, the release-notes line replaced, the branch added to `push.branches`, and `versionCode` untouched. Then `git checkout . && git checkout feature/copilot-android-workflow`.

- [ ] **Step 4: Confirm nothing in the plugin had to change**

```bash
cd /Users/ericcerio/Projects/Eplayment/ai-workflow && git status --porcelain
```
Expected: empty. Anything else means the portability goal failed; fix it in the plugin, not in the repo.

- [ ] **Step 5: Commit and open the PR**

```bash
cd /Users/ericcerio/Projects/Eplayment/eplayment-android
git add .ai AGENTS.md CLAUDE.md .github/copilot-instructions.md sync.sh
git commit -m "feat: adopt the AI context structure and the Copilot Android workflow"
git push -u origin feature/copilot-android-workflow
```

Then take one real bugfix through `/bugfix` and record the result.

---

## Notes carried from the spec

- **Accepted risk:** the AI and Agents Registry entry is tracked separately and gates nothing, so Task 18 may land before the entry exists. Recorded deliberately (spec §13).
- **Tracked separately:** rotating the credentials file tracked in PIXEL and the two keystores tracked in `eplayment-android`. This plan only lists them in `known_tracked_secrets`; it does not rotate anything.
- **Out of scope:** wiring ktlint into either build, installing `gh`, a Figma dev seat, Claude Code parity, `keri-android`, `mannypay-android`, the Flutter variant.
