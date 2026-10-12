# Multi-Host Portability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The same repository installs and runs on Copilot, Claude Code, Codex CLI and Gemini CLI, with the same skills, the same Jira MCP server and the same four rails enforced by one hook engine on every host.

**Architecture:** A new `hooks/codec.sh` detects which host called the hook, decodes its payload into the fields the rails already use (`KIND`, `CMD`, `EDIT_PATHS`) and encodes allow/deny/advise in that host's reply form. `guard-rails.sh` and `post-edit.sh` keep their logic and go through the codec. Per-host manifests, one merged `hooks/hooks.json`, MCP files and two marketplace files wire the hosts in. A canary command the hook always denies lets the chains prove the rails are live before anything is committed.

**Tech Stack:** bash (BSD and GNU compatible; no `jq`, no `python` in hooks), Markdown skills (Agent Skills format), Copilot CLI 1.0.89, Claude Code 2.1.288, Codex CLI and Gemini CLI (documentation only), Atlassian remote MCP server.

**Spec:** `docs/superpowers/specs/2026-10-12-multi-host-portability-design.md`

## Global Constraints

- `PLUGIN=/Users/ericcerio/Projects/Eplayment/ai-workflow` in every command below. Work on the branch `feat/multi-host-portability`.
- **Hooks use no `jq` and no `python`.** `sed` uses `-E` for alternation (BSD and GNU both have it). Every pattern added to a hook is exercised by `tests/run.sh` on macOS.
- **Copilot's verified deny form is unchanged:** `{"permissionDecision":"deny","permissionDecisionReason":"…"}` on stdout, **exit 0**. Copilot never receives exit 2.
- **Claude Code, Codex and Gemini deny with exit 2** and the reason on stderr; stdout also carries the host's JSON (section 5.2 of the spec).
- **Fail closed for git writes.** A hook that cannot load `lib.sh` or `codec.sh`, or that receives a payload it does not recognize, denies `git push`, `git commit`, `git add`, `git reset` and the canary, and allows everything else.
- **Canary command, verbatim:** `: android-workflow-rails-canary`. Deny reason begins `rails live`.
- **MCP:** server `atlassian`, URL `https://mcp.atlassian.com/v1/mcp`, no `headers`, `env`, token or any credential, in `mcp.json`, `.mcp.json` and `gemini-extension.json`.
- **No skill file and no `shared/*.md` other than `shared/hosts.md` names a host** (`Copilot`, `Claude Code`, `Codex`, `Gemini`) **or slash-invokes a workflow skill** (`/android-…`, `/ticket`, `/bugfix`). Skills are named in backticks without a slash.
- **Skills find shared files by the plugin root** (the nearest ancestor holding `plugin.json`), never by `../`.
- **Manifests:** `name` is `android-workflow` everywhere; marketplace name is `eplayment`. `version` is equal across `plugin.json`, `.claude-plugin/plugin.json` and `gemini-extension.json`.
- **Commits:** conventional (`feat:`, `test:`, `docs:`, `fix:`, `chore:`), ending with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`. **Never push, merge or tag without the user's explicit go**: everyone auto-updates from `main`.
- **Live runs cost credits and touch real tools.** Run them only in Tasks 1 and 9, only in scratch directories (`tests/fixtures/new-repo.sh`), never in a real app repository. Fixture repositories have no remote, so a push that slips through still goes nowhere.
- **Policy:** using Codex or Gemini on company work needs approval under `.ai/company/ai-usage-policy.md`. Nothing in this plan installs or runs Codex or Gemini.

## Review Focus

1. **Codex `apply_patch` text that mentions `git push` or `versionCode` in a non-Gradle file** must be allowed: the patch body is in `tool_input.command`, and treating it as a shell command would block ordinary edits. Test: `edit-readme-mentions-git.case` (Task 3) and `patch-non-gradle-versioncode.case` (Task 4).
2. **A Gemini payload that arrives without `--host gemini`** (a mis-wired `hooks.json`, a future Gemini that drops the arg) must still be answered in Gemini's form. Test: `raw-gemini-no-host-arg.case` (Task 3).
3. **A relative path in a patch** (`*** Update File: app/build.gradle`, how Codex usually writes it) must still trip the `versionCode` rail. Test: `patch-relative-gradle.case` (Task 4).
4. **The canary outside any configured repository, and chained to another command,** must be denied: a developer runs the rails check before onboarding, and a model may combine commands. Tests: `canary-no-config.case`, `canary-chained.case` (Task 5).
5. **Claude Code `MultiEdit`** carries its new text in an `edits[]` array, not a single `new_string`; a `versionCode` change in the second edit must still be denied. Test: `raw-claude-multiedit.case` (Task 3).

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `docs/checks/2026-10-12-claude-code-checks.md` | Evidence from the Claude Code probe and the live verification | 1, 9 |
| `tests/payloads/render.sh` | Renders a host-neutral case into one host's payload | 2 |
| `tests/run.sh` | Runs each case once per host; checks the reply form per host; fail-closed and fingerprint checks | 2, 3, 5 |
| `tests/cases/*.case` | Host-neutral cases (headers), or raw payload cases | 2–6 |
| `hooks/codec.sh` | `detect_host`, `decode`, `patch_paths`, `allow`, `deny`, `advise` | 3, 4 |
| `hooks/lib.sh` | Helpers only (`json_field`, `repo_root`, `cfg_list`, …); `allow`/`deny` move out | 3 |
| `hooks/guard-rails.sh` | The four rails, the canary, unknown-host and fail-closed handling | 3, 4, 5 |
| `hooks/post-edit.sh` | Advisory post-edit checks, per host | 6 |
| `hooks/hooks.json` | Claude Code, Codex and Gemini hook wiring, one file | 7 |
| `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` | Claude Code manifest and marketplace | 7 |
| `.agents/plugins/marketplace.json` | Codex marketplace | 7 |
| `gemini-extension.json` | Gemini manifest and MCP | 7 |
| `.mcp.json` | Claude Code MCP | 7 |
| `tests/lint-skills.sh` | Manifest, hook-wiring, MCP and skill-wording checks | 7, 8 |
| `shared/hosts.md` | Every per-host command, with sources | 8 |
| `shared/rails-check.md` | The canary step | 8 |
| `skills/**`, `shared/config.md`, `shared/ticket-file.md` | Host-neutral wording; rails check in four skills | 8 |
| `docs/checks/host-checklist.md` | The checks for whoever has an approved Codex or Gemini install | 9 |
| `README.md`, three manifests | Install per host, supported surfaces, policy line, `0.3.0` | 10 |

---

### Task 1: Probe Claude Code with a merged `hooks.json`

This is the spec's main risk (section 5.1). Its answer decides whether Tasks 7–10 go ahead as written.

**Files:**
- Create: `docs/checks/2026-10-12-claude-code-checks.md`
- Scratch only (not committed): `$SCRATCH/probe-plugin/…`, where `SCRATCH` is the session scratchpad directory

**Interfaces:**
- Produces: a recorded yes/no for (a) Claude Code loads a `hooks/hooks.json` that also holds `BeforeTool`/`AfterTool` keys, (b) `${CLAUDE_PLUGIN_ROOT:-$PLUGIN_ROOT}` resolves in a hook command, (c) exit 2 + stderr denies a Bash call, (d) the payload field names, (e) one plugin skill can invoke another.

- [ ] **Step 1: Build the probe plugin**

```bash
P="$SCRATCH/probe-plugin"; rm -rf "$P"; mkdir -p "$P/.claude-plugin" "$P/hooks" "$P/skills/probe-a" "$P/skills/probe-b"
printf '{"name":"probe","version":"0.0.1","description":"Hook and skill probe for android-workflow Task 1."}\n' > "$P/.claude-plugin/plugin.json"
cat > "$P/hooks/hooks.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT:-$PLUGIN_ROOT}/hooks/log.sh\"", "timeout": 10}]}
    ],
    "BeforeTool": [
      {"matcher": "run_shell_command", "hooks": [{"type": "command", "command": "\"${extensionPath}/hooks/log.sh\" --host gemini", "timeout": 10000}]}
    ]
  }
}
JSON
cat > "$P/hooks/log.sh" <<'SH'
#!/usr/bin/env bash
payload="$(cat)"
printf '%s\n' "$payload" >> "$(dirname "$0")/../payload.log"
case "$payload" in *probe-deny*) printf 'probe denied by hook\n' >&2; exit 2 ;; esac
printf '{}\n'
SH
chmod +x "$P/hooks/log.sh"
printf -- '---\nname: probe-a\ndescription: Probe skill A for the android-workflow Task 1 check; invokes probe-b.\n---\n\nRun the `probe-b` skill now, then report what it printed.\n' > "$P/skills/probe-a/SKILL.md"
printf -- '---\nname: probe-b\ndescription: Probe skill B for the android-workflow Task 1 check; prints a marker.\n---\n\nPrint exactly: PROBE-B-RAN\n' > "$P/skills/probe-b/SKILL.md"
```

- [ ] **Step 2: Validate the manifest**

Run: `claude plugin validate "$P"`
Expected: passes. Record the full output. Any error or warning that names `BeforeTool` is a **fail** for (a).

- [ ] **Step 3: Run the hook probe**

```bash
cd "$SCRATCH" && claude -p --plugin-dir "$P" --allowedTools Bash --debug \
  "Run the shell command: echo probe-allow. Then run the shell command: echo probe-deny. Report exactly what happened to each." \
  > "$SCRATCH/probe-run.txt" 2>&1; tail -40 "$SCRATCH/probe-run.txt"; cat "$P/payload.log"
```

If `--plugin-dir` is not a recognized flag, run `claude --help | grep -i plugin` and use the flag it lists for loading a plugin from a directory; record which.

Expected: `probe-allow` ran; `probe-deny` was blocked with "probe denied by hook"; `payload.log` has two lines with `tool_name`, `tool_input.command`, `cwd`; the debug output shows no error about `BeforeTool` or about the hook command. (a), (b), (c) pass only if all of these hold. Copy one payload line into the checks file as the observed shape (d).

- [ ] **Step 4: Run the skill-to-skill probe**

```bash
cd "$SCRATCH" && claude -p --plugin-dir "$P" "Run the probe-a skill." 2>&1 | tail -20
```

Expected: the output contains `PROBE-B-RAN`. That passes (e).

- [ ] **Step 5: Decide**

If (a), (b) or (c) failed: **stop the plan here** and report to the user with the evidence. The spec's fallback (a generated `gemini` branch) is a new design decision, not this plan's to make.

- [ ] **Step 6: Record and commit**

Write `docs/checks/2026-10-12-claude-code-checks.md` in the style of `docs/checks/2026-09-20-platform-checks.md`: Claude Code version (`claude --version`), a results table (a)–(e) with Pass/Fail, the observed payload line, and the exact commands run. Leave a heading `## Live verification` with the line "Recorded in Task 9." under it.

```bash
cd "$PLUGIN" && git add docs/checks/2026-10-12-claude-code-checks.md
git commit -m "docs: Claude Code probe — merged hooks.json, plugin root, exit-2 deny, skill calls

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Host-neutral cases and a per-host test runner (Copilot only)

A pure refactor of the tests: every existing case becomes host-neutral, the runner renders it for Copilot only, and all 22 checks (20 cases, fail-closed, fingerprint) still pass against the unchanged hooks. Tasks 3–6 widen the host list.

**Files:**
- Create: `tests/payloads/render.sh`
- Modify: `tests/run.sh` (rewrite)
- Modify: all 20 files in `tests/cases/`

**Interfaces:**
- Produces: case headers `expect`, `match`, `fixture`, `hook`, `kind` (`shell`|`edit`), `cmd`, `path`, `old`, `new`, `hosts` (space-separated subset), `reply` (for raw cases: the host whose reply form to expect: `copilot`|`claude`|`codex`|`gemini`|`unknown`); a case whose non-`#` lines are non-empty is a raw case and its body is the payload, with `$FIXTURE` substituted.
- Produces: `tests/payloads/render.sh <host> <case file> <fixture dir>` → one JSON payload line on stdout.
- Produces: `HOSTS` variable at the top of `tests/run.sh` — the hosts every rendered case runs against.

- [ ] **Step 1: Write the renderer**

`tests/payloads/render.sh`:

```bash
#!/usr/bin/env bash
# Renders a host-neutral case into the payload one host sends its tool hook.
# Usage: render.sh <copilot|claude|codex|gemini> <case file> <fixture dir>
# Shapes: spec 2026-10-12-multi-host-portability-design.md, section 4; Copilot's from
# docs/checks/2026-09-20-platform-checks.md.
set -eu
host="$1"; case_file="$2"; fx="$3"
hdr() { sed -n "s/^# $1: //p" "$case_file" | head -1 | sed "s#\$FIXTURE#${fx}#g"; }
esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
kind="$(hdr kind)"
cmd="$(esc "$(hdr cmd)")"; path="$(esc "$(hdr path)")"
old="$(esc "$(hdr old)")"; new="$(esc "$(hdr new)")"; cwd="$(esc "$fx")"
patch="*** Begin Patch\\n*** Update File: ${path}\\n@@\\n-${old}\\n+${new}\\n*** End Patch\\n"
case "$host:$kind" in
  copilot:shell) printf '{"sessionId":"s","timestamp":0,"cwd":"%s","toolName":"bash","toolArgs":{"command":"%s"}}\n' "$cwd" "$cmd" ;;
  copilot:edit)  printf '{"sessionId":"s","timestamp":0,"cwd":"%s","toolName":"str_replace_editor","toolArgs":{"path":"%s","old_str":"%s","new_str":"%s"}}\n' "$cwd" "$path" "$old" "$new" ;;
  claude:shell)  printf '{"session_id":"s","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}\n' "$cwd" "$cmd" ;;
  claude:edit)   printf '{"session_id":"s","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"%s","new_string":"%s"}}\n' "$cwd" "$path" "$old" "$new" ;;
  codex:shell)   printf '{"session_id":"s","turn_id":"t","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}\n' "$cwd" "$cmd" ;;
  codex:edit)    printf '{"session_id":"s","turn_id":"t","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"apply_patch","tool_input":{"command":"%s"}}\n' "$cwd" "$patch" ;;
  gemini:shell)  printf '{"session_id":"s","hook_event_name":"BeforeTool","cwd":"%s","tool_name":"run_shell_command","tool_input":{"command":"%s"}}\n' "$cwd" "$cmd" ;;
  gemini:edit)   printf '{"session_id":"s","hook_event_name":"BeforeTool","cwd":"%s","tool_name":"replace","tool_input":{"file_path":"%s","old_string":"%s","new_string":"%s"}}\n' "$cwd" "$path" "$old" "$new" ;;
  *) printf 'render.sh: no payload for %s\n' "$host:$kind" >&2; exit 1 ;;
esac
```

Run: `chmod +x tests/payloads/render.sh`

- [ ] **Step 2: Convert the cases**

Replace each case's JSON line with headers. The 20 files, exactly:

```
commit-on-develop.case          # expect: deny  # match: protected   # fixture: on-develop      # kind: shell  # cmd: git commit -m "x"
commit-on-feature.case          # expect: allow                      # fixture: on-feature      # kind: shell  # cmd: git commit -m "TA-1234: x"
edit-versioncode.case           # expect: deny  # match: versionCode # fixture: on-feature      # kind: edit   # path: $FIXTURE/app/build.gradle  # old: versionCode 60  # new: versionCode 61
edit-versionname.case           # expect: allow                      # fixture: on-feature      # kind: edit   # path: $FIXTURE/app/build.gradle  # old: versionName "3.4.27"  # new: versionName "3.4.28"
force-push-long.case            # expect: deny  # match: force       # fixture: on-feature      # kind: shell  # cmd: git push --force origin feature/TA-1234
force-push-short.case           # expect: deny  # match: force       # fixture: on-feature      # kind: shell  # cmd: git push -f origin feature/TA-1234
force-with-lease.case           # expect: deny  # match: force       # fixture: on-feature      # kind: shell  # cmd: git push --force-with-lease
git-add-dot-clean.case          # expect: allow                      # fixture: on-feature      # kind: shell  # cmd: git add .
git-add-dot-dirty-secret.case   # expect: deny  # match: firebase_credentials.json # fixture: dirty-secret # kind: shell # cmd: git add .
git-add-keystore.case           # expect: deny  # match: secret      # fixture: on-feature      # kind: shell  # cmd: git add app/release.keystore
gradle-command.case             # expect: allow                      # fixture: on-feature      # kind: shell  # cmd: ./gradlew testDebugUnitTest
narrowed-config-still-protects-main.case # expect: deny # match: protected # fixture: narrowed-config # kind: shell # cmd: git push origin main
outside-configured-repo.case    # expect: allow                      # fixture: no-config       # kind: shell  # cmd: git push origin develop
post-edit-no-checks.case        # expect: allow # hook: post-edit.sh # hosts: copilot # fixture: on-feature # kind: edit # path: $FIXTURE/app/build.gradle
post-edit-runs-check.case       # expect: allow # match: post-edit-check-ran # hook: post-edit.sh # hosts: copilot # fixture: with-post-edit-check # kind: edit # path: $FIXTURE/app/src/main/java/ui/Screen.kt
push-feature-branch.case        # expect: allow                      # fixture: on-feature      # kind: shell  # cmd: git push origin feature/TA-1234
push-no-target-on-develop.case  # expect: deny  # match: protected   # fixture: on-develop      # kind: shell  # cmd: git push
push-plus-refspec.case          # expect: deny  # match: force       # fixture: on-feature      # kind: shell  # cmd: git push origin +feature/TA-1234
push-to-develop-explicit.case   # expect: deny  # match: protected   # fixture: on-feature      # kind: shell  # cmd: git push origin develop
sed-versioncode.case            # expect: deny  # match: versionCode # fixture: on-feature      # kind: shell  # cmd: sed -i '' 's/versionCode 60/versionCode 61/' app/build.gradle
```

The two post-edit cases carry `# hosts: copilot` until Task 6 teaches `post-edit.sh` the other hosts.

One header per line in the file. For example `tests/cases/edit-versioncode.case` becomes:

```
# expect: deny
# match: versionCode
# fixture: on-feature
# kind: edit
# path: $FIXTURE/app/build.gradle
# old: versionCode 60
# new: versionCode 61
```

- [ ] **Step 3: Rewrite the runner**

`tests/run.sh`:

```bash
#!/usr/bin/env bash
# Runs every tests/cases/*.case against its hook once per host, with the payload that host sends
# (tests/payloads/render.sh), and checks the reply is in that host's form. A case with a body is a
# raw payload, run once, its reply form named by '# reply:'.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOSTS="copilot"
pass=0; fail=0
errf="$(mktemp)"
hdr() { sed -n "s/^# $1: //p" "$2" | head -1; }

# verdict <label> <host> <hook> <expect> <match> <rc> <stdout> <stderr>
verdict() {
  label="$1"; host="$2"; hook="$3"; expect="$4"; match="$5"; rc="$6"; out="$7"; err="$8"; why=""
  if [ "$expect" = deny ]; then
    case "$host" in
      copilot) [ "$rc" -eq 0 ] || why="$why exit=$rc(want 0);"
               case "$out" in *'"permissionDecision":"deny"'*) ;; *) why="$why no copilot deny on stdout;" ;; esac ;;
      claude|codex)
               [ "$rc" -eq 2 ] || why="$why exit=$rc(want 2);"
               case "$out" in *'"hookSpecificOutput"'*'"permissionDecision":"deny"'*) ;; *) why="$why no hookSpecificOutput deny;" ;; esac ;;
      gemini)  [ "$rc" -eq 2 ] || why="$why exit=$rc(want 2);"
               case "$out" in *'"decision":"deny"'*) ;; *) why="$why no gemini decision deny;" ;; esac ;;
      unknown) [ "$rc" -eq 2 ] || why="$why exit=$rc(want 2);"
               case "$out" in *'"permissionDecision":"deny"'*'"decision":"deny"'*) ;; *) why="$why not denied in every form;" ;; esac ;;
    esac
    if [ -n "$match" ]; then
      case "$host" in
        copilot) case "$out" in *"$match"*) ;; *) why="$why '$match' not on stdout;" ;; esac ;;
        *)       case "$err" in *"$match"*) ;; *) why="$why '$match' not on stderr;" ;; esac ;;
      esac
    fi
  else
    [ "$rc" -eq 0 ] || why="$why exit=$rc(want 0);"
    case "$out" in *'"deny"'*) why="$why denied;" ;; esac
    if [ -n "$match" ]; then
      case "$out" in *"$match"*) ;; *) why="$why '$match' not on stdout;" ;; esac
      if [ "$hook" = post-edit.sh ]; then
        case "$host" in
          copilot) key='"additionalContext"' ;;
          claude|codex) key='"hookSpecificOutput"' ;;
          gemini) key='"systemMessage"' ;;
          *) key='' ;;
        esac
        case "$out" in *"$key"*) ;; *) why="$why advice not in $host form;" ;; esac
      fi
    fi
  fi
  if [ -z "$why" ]; then pass=$((pass+1)); else
    fail=$((fail+1)); printf 'FAIL %s\n  %s\n  stdout: %s\n  stderr: %s\n' "$label" "$why" "$out" "$err"
  fi
}

# run_one <label> <host> <hook> <expect> <match> <payload> [hook args…]
run_one() {
  label="$1"; host="$2"; hook="$3"; expect="$4"; match="$5"; payload="$6"; shift 6
  out="$(printf '%s' "$payload" | "$root/hooks/$hook" "$@" 2>"$errf")"; rc=$?
  verdict "$label" "$host" "$hook" "$expect" "$match" "$rc" "$out" "$(cat "$errf")"
}

for case_file in "$root"/tests/cases/*.case; do
  name="$(basename "$case_file" .case)"
  expect="$(hdr expect "$case_file")"; match="$(hdr match "$case_file")"
  fixture="$(hdr fixture "$case_file")"
  hook="$(hdr hook "$case_file")"; hook="${hook:-guard-rails.sh}"
  only="$(hdr hosts "$case_file")"
  if [ ! -x "$root/hooks/$hook" ]; then
    printf 'FAIL %s\n  hook not executable: hooks/%s\n' "$name" "$hook"; fail=$((fail+1)); continue
  fi
  dir=""; [ -n "$fixture" ] && dir="$("$root/tests/fixtures/new-repo.sh" "$fixture")"
  raw="$(grep -v '^#' "$case_file" | grep -v '^[[:space:]]*$' || true)"
  if [ -n "$raw" ]; then
    reply="$(hdr reply "$case_file")"
    run_one "$name" "$reply" "$hook" "$expect" "$match" "$(printf '%s' "$raw" | sed "s#\$FIXTURE#${dir}#g")"
  else
    for host in ${only:-$HOSTS}; do
      payload="$("$root/tests/payloads/render.sh" "$host" "$case_file" "$dir")"
      if [ "$host" = gemini ]; then
        run_one "$name[$host]" "$host" "$hook" "$expect" "$match" "$payload" --host gemini
      else
        run_one "$name[$host]" "$host" "$hook" "$expect" "$match" "$payload"
      fi
    done
  fi
  [ -n "$dir" ] && rm -rf "$dir"
done

# Fail-closed: a hook that cannot load its library must still block git writes.
lib="$root/hooks/lib.sh"
chmod 000 "$lib"
fc_out="$(printf '{"cwd":"%s","toolName":"bash","toolArgs":{"command":"git push origin feature/x"}}' "$root" | "$root/hooks/guard-rails.sh" 2>/dev/null)"
chmod 644 "$lib"
case "$fc_out" in
  *'"deny"'*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); printf 'FAIL fail-closed-without-lib\n  expected: deny\n  got: %s\n' "$fc_out" ;;
esac
```

Then append the existing fingerprint block unchanged (from `# The diff fingerprint, taken from its contract` through `rm -rf "$fp_dir"`), and end with:

```bash
rm -f "$errf"
printf '%d passed, %d failed\n' "$pass" "$fail"
[ $fail -eq 0 ]
```

- [ ] **Step 4: Run and confirm nothing changed**

Run: `./tests/run.sh`
Expected: `22 passed, 0 failed` — the same as before the refactor (20 cases on Copilot, fail-closed, fingerprint). Any FAIL is a bug in the renderer or the case conversion; compare the rendered payload (`tests/payloads/render.sh copilot tests/cases/<name>.case /tmp/x`) with the case's old JSON line in `git show HEAD:tests/cases/<name>.case` and fix before moving on.

- [ ] **Step 5: Commit**

```bash
git add tests/payloads/render.sh tests/run.sh tests/cases
git commit -m "test: host-neutral hook cases, rendered per host by tests/payloads/render.sh

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: The codec — Claude Code, Codex and Gemini shell and edit payloads

**Files:**
- Create: `hooks/codec.sh`
- Modify: `hooks/lib.sh` (remove `allow` and `deny`; header comment)
- Modify: `hooks/guard-rails.sh`
- Modify: `tests/run.sh` (`HOSTS`)
- Create: `tests/cases/edit-readme-mentions-git.case`, `tests/cases/raw-gemini-no-host-arg.case`, `tests/cases/raw-claude-multiedit.case`

**Interfaces:**
- Consumes: `json_field <json> <key>` from `hooks/lib.sh`.
- Produces (in `hooks/codec.sh`, used by Tasks 4–6):
  - `detect_host <payload> [explicit]` → prints `copilot`|`claude`|`gemini`|`unknown`
  - `decode <payload>` → sets globals `TOOL`, `KIND` (`shell`|`edit`|`other`), `CMD`, `EDIT_PATHS` (newline-separated)
  - `allow` → `{}`, exit 0
  - `deny <reason>` → reply in `$HOOK_HOST`'s form, exits
  - `advise <text>` → advisory context in `$HOOK_HOST`'s form, exit 0
  - global `HOOK_HOST`, set by the hook script from `detect_host`

- [ ] **Step 1: Widen the hosts and add the new cases**

In `tests/run.sh` change `HOSTS="copilot"` to `HOSTS="copilot claude codex gemini"`.

`tests/cases/edit-readme-mentions-git.case`:

```
# expect: allow
# fixture: on-feature
# kind: edit
# path: $FIXTURE/README.md
# old: Push your branch.
# new: Run git push origin develop only through a release.
```

`tests/cases/raw-gemini-no-host-arg.case`:

```
# expect: deny
# match: protected
# fixture: on-feature
# reply: gemini
{"session_id":"s","hook_event_name":"BeforeTool","cwd":"$FIXTURE","tool_name":"run_shell_command","tool_input":{"command":"git push origin develop"}}
```

`tests/cases/raw-claude-multiedit.case`:

```
# expect: deny
# match: versionCode
# fixture: on-feature
# reply: claude
{"session_id":"s","hook_event_name":"PreToolUse","cwd":"$FIXTURE","tool_name":"MultiEdit","tool_input":{"file_path":"$FIXTURE/app/build.gradle","edits":[{"old_string":"versionName \"3.4.27\"","new_string":"versionName \"3.4.28\""},{"old_string":"versionCode 60","new_string":"versionCode 61"}]}}
```

- [ ] **Step 2: Run to see it fail**

Run: `./tests/run.sh`
Expected: FAIL lines for every `deny` case on `[claude]`, `[codex]` and `[gemini]` (exit 0 instead of 2, Copilot JSON instead of the host's), for `raw-gemini-no-host-arg` and `raw-claude-multiedit`; and for `edit-versioncode[codex]` (the patch path is not read). Copilot rows pass.

- [ ] **Step 3: Write `hooks/codec.sh`**

```bash
#!/usr/bin/env bash
# Host codec: which tool called the hook, what it asked for, and how to answer it.
# Sourced after lib.sh by guard-rails.sh and post-edit.sh. Payload shapes and reply forms:
# docs/superpowers/specs/2026-10-12-multi-host-portability-design.md, sections 4 and 5.2.
#
#   copilot  {"toolName":"bash","toolArgs":{"command":…}}                 deny: JSON on stdout, exit 0
#   claude   {"tool_name":"Bash","tool_input":{…}}  — Claude Code and Codex  deny: stderr, exit 2
#   gemini   {"tool_name":"run_shell_command","tool_input":{…}}             deny: stderr, exit 2
#   unknown  anything else                                                  deny: every form, exit 2

# detect_host <payload> [explicit] — the explicit --host value wins; otherwise the payload's shape.
detect_host() {
  if [ -n "${2:-}" ]; then printf '%s' "$2"; return; fi
  case "$1" in
    *'"toolArgs"'*) printf 'copilot' ;;
    *'"tool_input"'*)
      case "$(json_field "$1" tool_name)" in
        run_shell_command|write_file|replace) printf 'gemini' ;;
        *) printf 'claude' ;;
      esac ;;
    *) printf 'unknown' ;;
  esac
}

# patch_paths <patch text, JSON-escaped> — the files an apply_patch adds, updates or moves to.
patch_paths() {
  printf '%s' "$1" | awk '{ gsub(/\\n/, "\n"); print }' \
    | sed -n -E -e 's/^\*\*\* (Add|Update) File: (.*)$/\2/p' -e 's/^\*\*\* Move to: (.*)$/\1/p'
}

# decode <payload> — sets TOOL, KIND (shell|edit|other), CMD and EDIT_PATHS (one per line).
# Only a shell tool has a CMD: an apply_patch also carries its text in "command", and that text is
# file content, not something about to run.
decode() {
  TOOL="$(json_field "$1" toolName)"; [ -n "$TOOL" ] || TOOL="$(json_field "$1" tool_name)"
  KIND=other; CMD=""; EDIT_PATHS=""
  case "$TOOL" in
    bash|Bash|run_shell_command)
      KIND=shell; CMD="$(json_field "$1" command)" ;;
    apply_patch)
      KIND=edit
      EDIT_PATHS="$(printf '%s\n%s\n%s\n' "$(json_field "$1" path)" "$(json_field "$1" file_path)" \
                    "$(patch_paths "$(json_field "$1" command)$(json_field "$1" input)")" \
                    | grep -v '^$' || true)" ;;
    edit|create|str_replace_editor|write|Edit|Write|MultiEdit|write_file|replace)
      KIND=edit
      EDIT_PATHS="$(json_field "$1" path)"; [ -n "$EDIT_PATHS" ] || EDIT_PATHS="$(json_field "$1" file_path)" ;;
  esac
}

# allow — let the call run.
allow() { printf '{}\n'; exit 0; }

# deny <reason> — block the call in the form HOOK_HOST understands.
deny() {
  r="$(printf '%s' "$1" | sed 's/"/\\"/g')"
  case "${HOOK_HOST:-unknown}" in
    copilot) printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$r"; exit 0 ;;
    claude)  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$r" ;;
    gemini)  printf '{"decision":"deny","reason":"%s"}\n' "$r" ;;
    *)       printf '{"permissionDecision":"deny","permissionDecisionReason":"%s","decision":"deny","reason":"%s"}\n' "$r" "$r" ;;
  esac
  printf '%s\n' "$1" >&2
  exit 2
}

# advise <text> — advisory context for the model after an edit. Never blocks.
advise() {
  t="$(printf '%s' "$1" | sed 's/"/\\"/g' | tr '\n' ' ')"
  case "${HOOK_HOST:-unknown}" in
    copilot) printf '{"additionalContext":"%s"}\n' "$t" ;;
    claude)  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$t" ;;
    gemini)  printf '{"systemMessage":"%s"}\n' "$t" ;;
    *)       printf '{}\n' ;;
  esac
  exit 0
}
```

- [ ] **Step 4: Move `allow`/`deny` out of `lib.sh`**

In `hooks/lib.sh`, delete these two lines:

```bash
allow() { printf '{}\n'; exit 0; }
deny()  { printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' \
            "$(printf '%s' "$1" | sed 's/"/\\"/g')"; exit 0; }
```

In `hooks/post-edit.sh`, which calls `allow`, change its library line to

```bash
{ . "$DIR/lib.sh" && . "$DIR/codec.sh"; } 2>/dev/null || { printf '{}\n'; exit 0; }
```

and add `HOOK_HOST=copilot` on the next line (Task 6 replaces both). In `lib.sh`, change the header comment's first line to `# Shared helpers for the hooks. No jq, no python: neither is guaranteed on a dev Mac.` and add under the payload-shape comment: `# Other hosts' shapes, and allow/deny/advise: codec.sh.`

- [ ] **Step 5: Route `guard-rails.sh` through the codec**

Replace everything from `payload="$(cat)"` down to and including the line `path="$(json_field "$payload" path)"; [ -n "$path" ] || path="$(json_field "$payload" file_path)"` with:

```bash
payload="$(cat)"
explicit=""; [ "${1:-}" = "--host" ] && explicit="${2:-}"

# Catastrophic path: the library is what defines allow/deny, so it cannot be relied on to report
# its own absence. Emit a decision here, before sourcing, or a broken install silently allows.
# Copilot's form for a Copilot payload (exit 0, verified); every other form, with exit 2, otherwise.
fail_closed() {
  case "$payload" in
    *"git push"*|*"git commit"*|*"git add"*|*"git reset"*)
      r="guard-rails hook could not load its library; blocking this git command. Reinstall the plugin."
      case "$payload" in
        *'"toolArgs"'*) printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$r"; exit 0 ;;
      esac
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"},"decision":"deny","reason":"%s"}\n' "$r" "$r"
      printf '%s\n' "$r" >&2
      exit 2 ;;
  esac
  printf '{}\n'
  exit 0
}
{ . "$DIR/lib.sh" && . "$DIR/codec.sh"; } 2>/dev/null || fail_closed

HOOK_HOST="$(detect_host "$payload" "$explicit")"
decode "$payload"
cwd="$(json_field "$payload" cwd)"; [ -n "$cwd" ] || cwd="$PWD"
cmd="$CMD"
```

Change the shell-rails guard from `if [ -n "$cmd" ]; then` to:

```bash
if [ "$KIND" = shell ] && [ -n "$cmd" ]; then
```

Replace the final file-edit block (from `# File edits: versionCode inside a Gradle file.` through the closing `esac` before `allow`) with:

```bash
# File edits: versionCode inside a Gradle file. The whole payload is searched, not one field, so an
# edit list (MultiEdit) or a patch is covered as well as a single replacement.
if [ "$KIND" = edit ]; then
  case "$payload" in
    *versionCode*)
      if printf '%s\n' "$EDIT_PATHS" | grep -qE '\.gradle(\.kts)?$'; then
        deny "Blocked: versionCode is owned by CI and release, never by this workflow."
      fi ;;
  esac
fi
```

- [ ] **Step 6: Run the tests**

Run: `./tests/run.sh`
Expected: `0 failed`. The total is 4 × (number of rendered case files) + the raw cases + fail-closed + fingerprint; record the number for Task 10's README.

- [ ] **Step 7: Commit**

```bash
git add hooks/codec.sh hooks/lib.sh hooks/guard-rails.sh tests/run.sh tests/cases
git commit -m "feat: hook codec — the rails answer Claude Code, Codex and Gemini in their own form

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `apply_patch` paths

Task 3 made the Codex `edit-versioncode` row pass through `patch_paths`. This task pins the patch cases that row does not cover.

**Files:**
- Create: `tests/cases/patch-relative-gradle.case`, `tests/cases/patch-non-gradle-versioncode.case`, `tests/cases/raw-codex-add-kts.case`
- Modify (only if a case fails): `hooks/codec.sh` (`patch_paths`)

**Interfaces:**
- Consumes: `patch_paths`, `decode`, `KIND`, `EDIT_PATHS` from Task 3.

- [ ] **Step 1: Write the cases**

`tests/cases/patch-relative-gradle.case`:

```
# expect: deny
# match: versionCode
# fixture: on-feature
# hosts: codex
# kind: edit
# path: app/build.gradle
# old: versionCode 60
# new: versionCode 61
```

`tests/cases/patch-non-gradle-versioncode.case`:

```
# expect: allow
# fixture: on-feature
# hosts: codex claude gemini copilot
# kind: edit
# path: $FIXTURE/docs/release.md
# old: The version code is bumped by CI.
# new: versionCode is bumped by CI, never by hand.
```

`tests/cases/raw-codex-add-kts.case` — a new Kotlin-DSL Gradle file added by patch, with a `Move to` line in the same patch:

```
# expect: deny
# match: versionCode
# fixture: on-feature
# reply: codex
{"session_id":"s","turn_id":"t","hook_event_name":"PreToolUse","cwd":"$FIXTURE","tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: notes.txt\n*** Move to: docs/notes.txt\n@@\n-a\n+b\n*** Add File: feature/build.gradle.kts\n+android { defaultConfig { versionCode = 1 } }\n*** End Patch\n"}}
```

- [ ] **Step 2: Run them**

Run: `./tests/run.sh 2>&1 | grep -E 'patch-|raw-codex|passed'`
Expected: all pass with Task 3's code. If `raw-codex-add-kts` fails, run
`printf '%s' '*** Begin Patch\n*** Add File: feature/build.gradle.kts\n' | (. hooks/lib.sh; . hooks/codec.sh; patch_paths "$(cat)")`
— it must print `feature/build.gradle.kts`; fix `patch_paths` until it does, then rerun.

- [ ] **Step 3: Commit**

```bash
git add tests/cases hooks/codec.sh
git commit -m "test: apply_patch — relative, added and moved Gradle paths; prose about versionCode allowed

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: The canary, unknown payloads, and fail-closed on every host

**Files:**
- Modify: `hooks/guard-rails.sh`
- Modify: `tests/run.sh` (fail-closed block)
- Create: `tests/cases/canary-no-config.case`, `tests/cases/canary-configured.case`, `tests/cases/canary-chained.case`, `tests/cases/raw-unknown-push.case`, `tests/cases/raw-unknown-ls.case`

**Interfaces:**
- Consumes: `deny`, `allow`, `HOOK_HOST`, `KIND`, `CMD` from Task 3; `render.sh` from Task 2.
- Produces: the canary contract used by `shared/rails-check.md` (Task 8): the command `: android-workflow-rails-canary` is denied on every host, with a reason beginning `rails live`, inside and outside configured repositories; with the library missing it is denied with the fail-closed reason.

- [ ] **Step 1: Write the cases**

`tests/cases/canary-no-config.case`:

```
# expect: deny
# match: rails live
# fixture: no-config
# kind: shell
# cmd: : android-workflow-rails-canary
```

`tests/cases/canary-configured.case`:

```
# expect: deny
# match: rails live
# fixture: on-feature
# kind: shell
# cmd: : android-workflow-rails-canary
```

`tests/cases/canary-chained.case`:

```
# expect: deny
# match: rails live
# fixture: on-feature
# kind: shell
# cmd: : android-workflow-rails-canary && git status
```

`tests/cases/raw-unknown-push.case`:

```
# expect: deny
# match: did not recognize
# fixture: on-feature
# reply: unknown
{"cwd":"$FIXTURE","tool":"shell","args":{"command":"git push origin feature/TA-1234"}}
```

`tests/cases/raw-unknown-ls.case`:

```
# expect: allow
# fixture: on-feature
# reply: unknown
{"cwd":"$FIXTURE","tool":"shell","args":{"command":"ls"}}
```

- [ ] **Step 2: Extend the fail-closed check to every host and to the canary**

In `tests/run.sh`, replace the fail-closed block (from `# Fail-closed: a hook that cannot load its library` through its closing `esac`) with:

```bash
# Fail-closed: a hook that cannot load lib.sh or codec.sh must still block git writes and the
# canary, on every host, in that host's form.
fc_case="$(mktemp)"
for broken in lib.sh codec.sh; do
  for cmd in 'git push origin feature/x' ': android-workflow-rails-canary'; do
    printf '# kind: shell\n# cmd: %s\n' "$cmd" > "$fc_case"
    chmod 000 "$root/hooks/$broken"
    for host in $HOSTS; do
      payload="$("$root/tests/payloads/render.sh" "$host" "$fc_case" "$root")"
      if [ "$host" = gemini ]; then
        run_one "fail-closed-$broken[$host] $cmd" "$host" guard-rails.sh deny "could not load" "$payload" --host gemini
      else
        run_one "fail-closed-$broken[$host] $cmd" "$host" guard-rails.sh deny "could not load" "$payload"
      fi
    done
    chmod 644 "$root/hooks/$broken"
  done
done
rm -f "$fc_case"
```

`run_one` must be defined above this block (it is, from Task 2). With `chmod 000` the render step does not touch the hooks, so it still works.

- [ ] **Step 3: Run to see it fail**

Run: `./tests/run.sh 2>&1 | grep -E 'FAIL (canary|raw-unknown|fail-closed)|passed'`
Expected: the three canary cases fail on every host (the hook allows `:` commands outside a configured repo and has no canary rule); `raw-unknown-push` fails (unknown host: `CMD` is empty, so it allows); fail-closed rows with the canary command fail (the fail-closed path matches git writes only).

- [ ] **Step 4: Implement**

In `hooks/guard-rails.sh`, in `fail_closed`, change the pattern line to:

```bash
    *android-workflow-rails-canary*|*"git push"*|*"git commit"*|*"git add"*|*"git reset"*)
```

and change its message to `"guard-rails hook could not load its library; blocking this command. Reinstall the plugin."`. (The test matches `could not load`.)

Directly after `decode "$payload"`, add:

```bash
# The canary (shared/rails-check.md) proves this hook runs. It is answered before anything else, in
# every repository, so the answer depends on nothing but the hook being wired in.
case "$payload" in
  *android-workflow-rails-canary*) deny "rails live: the android-workflow guard hook is running." ;;
esac
```

Directly after the line `cmd="$CMD"`, add:

```bash
# A payload in no known shape: the rails cannot be applied, so git writes are refused rather than
# waved through. Its command is still findable for that one decision.
[ "$HOOK_HOST" = unknown ] && cmd="$(json_field "$payload" command)"
```

Directly after `cfg="$root/.ai/project/android-workflow.yml"`, add:

```bash
if [ "$HOOK_HOST" = unknown ]; then
  [ "$writes_git" -eq 1 ] && deny "Blocked: the guard hook did not recognize this tool's payload, so it cannot check this git command. Run tests/run.sh."
  allow
fi
```

- [ ] **Step 5: Run the tests**

Run: `./tests/run.sh`
Expected: `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add hooks/guard-rails.sh tests/run.sh tests/cases
git commit -m "feat: rails canary, and unknown payloads fail closed for git writes on every host

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `post-edit.sh` on every host

**Files:**
- Modify: `hooks/post-edit.sh`
- Create: `tests/cases/raw-codex-post-edit-patch.case`

**Interfaces:**
- Consumes: `detect_host`, `decode`, `EDIT_PATHS`, `allow`, `advise`, `HOOK_HOST` from Task 3.

- [ ] **Step 1: Widen the post-edit cases, write the new one, and run**

Delete the `# hosts: copilot` line from `tests/cases/post-edit-no-checks.case` and `tests/cases/post-edit-runs-check.case`.

`tests/cases/raw-codex-post-edit-patch.case` — one patch, two files, the check must run on both:

```
# expect: allow
# match: Screen.kt
# hook: post-edit.sh
# fixture: with-post-edit-check
# reply: codex
{"session_id":"s","turn_id":"t","hook_event_name":"PostToolUse","cwd":"$FIXTURE","tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: app/build.gradle\n@@\n-a\n+b\n*** Update File: app/src/main/java/ui/Screen.kt\n@@\n-a\n+b\n*** End Patch\n"}}
```

Run: `./tests/run.sh 2>&1 | grep -E 'FAIL post-edit|FAIL raw-codex-post|passed'`
Expected: `post-edit-runs-check[claude|codex|gemini]` fail (advice not in the host form; Codex/Claude Code/Gemini tool names not in the hook's list), and `raw-codex-post-edit-patch` fails.

- [ ] **Step 2: Route `post-edit.sh` through the codec**

Replace the body of `hooks/post-edit.sh` from `payload="$(cat)"` to the end with:

```bash
payload="$(cat)"
explicit=""; [ "${1:-}" = "--host" ] && explicit="${2:-}"

# A broken library must not break editing: this hook allows on any failure.
{ . "$DIR/lib.sh" && . "$DIR/codec.sh"; } 2>/dev/null || { printf '{}\n'; exit 0; }

HOOK_HOST="$(detect_host "$payload" "$explicit")"
decode "$payload"
[ "$KIND" = edit ] || allow
[ -n "$EDIT_PATHS" ] || allow

cwd="$(json_field "$payload" cwd)"; [ -n "$cwd" ] || cwd="$PWD"
root="$(repo_root "$cwd")" || allow
[ -n "$root" ] || allow
has_workflow_config "$root" || allow

checks="$(cfg_list "$root/.ai/project/android-workflow.yml" "  post_edit_checks")"
out=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  while IFS= read -r check; do
    [ -n "$check" ] || continue
    [ -x "$root/$check" ] || continue
    result="$("$root/$check" "$file" 2>&1)" || true
    [ -n "$result" ] && out="$out$result
"
  done <<EOF
$checks
EOF
done <<EOF
$EDIT_PATHS
EOF

[ -n "$out" ] && advise "$out"
allow
```

- [ ] **Step 3: Run the tests**

Run: `./tests/run.sh`
Expected: `0 failed`.

- [ ] **Step 4: Commit**

```bash
git add hooks/post-edit.sh tests/cases
git commit -m "feat: post-edit checks answer every host, and run on each file a patch touches

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Manifests, hook wiring, MCP and marketplaces

**Files:**
- Create: `hooks/hooks.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.agents/plugins/marketplace.json`, `gemini-extension.json`, `.mcp.json`
- Modify: `tests/lint-skills.sh`

**Interfaces:**
- Consumes: `hooks/guard-rails.sh` and `hooks/post-edit.sh` accept `--host gemini` (Tasks 3, 6).
- Produces: lint function `manifest_field <file> <key>` (first string value of a top-level key) used in Task 10's version check.

- [ ] **Step 1: Write the lint checks first**

In `tests/lint-skills.sh`, replace the block from `# Plugin MCP servers (check 7)` to just before `[ $fail -eq 0 ] && echo "skill lint: OK"` with:

```bash
# MCP servers. Copilot and Codex read mcp.json, Claude Code .mcp.json, Gemini its manifest. Each
# declares the Atlassian server by URL, never a credential — each developer signs in.
for f in mcp.json .mcp.json gemini-extension.json; do
  [ -e "$root/$f" ] || { note "$f: missing"; continue; }
  grep -q '"mcpServers"' "$root/$f" || note "$f: no mcpServers object"
  grep -q 'https://mcp.atlassian.com/v1/mcp' "$root/$f" || note "$f: does not declare the Atlassian server"
  grep -qiE '"(headers|env|authorization|token|apikey|api_key|password|secret)"' "$root/$f" \
    && note "$f: declares headers or credentials; each developer signs in instead"
done

# Manifests: one name everywhere, one version across the three manifests.
manifest_field() { sed -n -E "s/^[[:space:]]*\"$2\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" "$1" | head -1; }
for f in plugin.json .claude-plugin/plugin.json gemini-extension.json; do
  [ -e "$root/$f" ] || { note "$f: missing"; continue; }
  [ "$(manifest_field "$root/$f" name)" = android-workflow ] || note "$f: name is not android-workflow"
done
v="$(manifest_field "$root/plugin.json" version)"
for f in .claude-plugin/plugin.json gemini-extension.json; do
  [ -e "$root/$f" ] && [ "$(manifest_field "$root/$f" version)" != "$v" ] && note "$f: version differs from plugin.json ($v)"
done
for f in .claude-plugin/marketplace.json .agents/plugins/marketplace.json; do
  [ -e "$root/$f" ] || { note "$f: missing"; continue; }
  grep -q '"name": "android-workflow"' "$root/$f" || note "$f: does not list android-workflow"
done

# Hook wiring. Each event's matcher must name every tool that host uses to run a shell command or
# edit a file, or a rail is silently skipped there. One entry per event, matcher on its own line.
hj="$root/hooks/hooks.json"
matcher_of() { grep -A3 "\"$1\"" "$hj" | sed -n -E 's/.*"matcher": "([^"]*)".*/\1/p' | head -1; }
if [ -e "$hj" ]; then
  for t in Bash Edit Write MultiEdit apply_patch; do
    printf '%s' "|$(matcher_of PreToolUse)|" | grep -q "|$t|" || note "hooks/hooks.json: PreToolUse matcher misses $t"
  done
  for t in run_shell_command write_file replace; do
    printf '%s' "|$(matcher_of BeforeTool)|" | grep -q "|$t|" || note "hooks/hooks.json: BeforeTool matcher misses $t"
  done
  for t in Edit Write MultiEdit apply_patch; do
    printf '%s' "|$(matcher_of PostToolUse)|" | grep -q "|$t|" || note "hooks/hooks.json: PostToolUse matcher misses $t"
  done
  for t in write_file replace; do
    printf '%s' "|$(matcher_of AfterTool)|" | grep -q "|$t|" || note "hooks/hooks.json: AfterTool matcher misses $t"
  done
else
  note "hooks/hooks.json: missing"
fi
for f in "$hj" "$root/com.github.copilot/hooks/hooks.json"; do
  [ -e "$f" ] || continue
  while read -r ref; do
    [ -x "$root/$ref" ] || note "${f#"$root"/}: runs $ref, which is missing or not executable"
  done < <(grep -oE 'hooks/[a-z-]+\.sh' "$f" | sort -u)
done
```

Run: `./tests/lint-skills.sh`
Expected: FAIL — missing `.mcp.json`, `gemini-extension.json`, `.claude-plugin/plugin.json`, both marketplaces, `hooks/hooks.json`.

- [ ] **Step 2: Write `hooks/hooks.json`**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write|MultiEdit|apply_patch",
        "hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT:-$PLUGIN_ROOT}/hooks/guard-rails.sh\"", "timeout": 10}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|apply_patch",
        "hooks": [{"type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT:-$PLUGIN_ROOT}/hooks/post-edit.sh\"", "timeout": 30}]
      }
    ],
    "BeforeTool": [
      {
        "matcher": "run_shell_command|write_file|replace",
        "hooks": [{"type": "command", "command": "\"${extensionPath}/hooks/guard-rails.sh\" --host gemini", "timeout": 10000}]
      }
    ],
    "AfterTool": [
      {
        "matcher": "write_file|replace",
        "hooks": [{"type": "command", "command": "\"${extensionPath}/hooks/post-edit.sh\" --host gemini", "timeout": 30000}]
      }
    ]
  }
}
```

Claude Code and Codex time out in seconds, Gemini in milliseconds; the values above are the same 10 s and 30 s as Copilot's.

- [ ] **Step 3: Write the manifests, MCP and marketplaces**

`.claude-plugin/plugin.json`:

```json
{
  "name": "android-workflow",
  "version": "0.2.0",
  "description": "Eplayment Android development workflow: Jira intake with the related BE and UI tickets, plan, branch, lint, version, test, code review, security gate, commit and push, distribution note. Every stage runs on its own, or as one chain with the ticket and bugfix skills."
}
```

`.claude-plugin/marketplace.json`:

```json
{
  "name": "eplayment",
  "owner": { "name": "Eplayment R&D" },
  "plugins": [
    {
      "name": "android-workflow",
      "source": "./",
      "description": "Eplayment Android development workflow, from Jira ticket to distribution note, with hook-enforced rails."
    }
  ]
}
```

`.agents/plugins/marketplace.json`:

```json
{
  "name": "eplayment",
  "interface": { "displayName": "Eplayment" },
  "plugins": [
    {
      "name": "android-workflow",
      "source": { "source": "local", "path": "./" },
      "policy": { "installation": "AVAILABLE", "authentication": "ON_INSTALL" },
      "category": "Productivity"
    }
  ]
}
```

`gemini-extension.json`:

```json
{
  "name": "android-workflow",
  "version": "0.2.0",
  "description": "Eplayment Android development workflow: Jira intake with the related BE and UI tickets, plan, branch, lint, version, test, code review, security gate, commit and push, distribution note.",
  "mcpServers": {
    "atlassian": {
      "httpUrl": "https://mcp.atlassian.com/v1/mcp"
    }
  }
}
```

`.mcp.json`:

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

- [ ] **Step 4: Validate**

Run: `./tests/lint-skills.sh && claude plugin validate "$PLUGIN" && ./tests/run.sh | tail -1`
Expected: `skill lint: OK`; validate passes (record any warning in the checks file under Task 9); `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add hooks/hooks.json .claude-plugin .agents gemini-extension.json .mcp.json tests/lint-skills.sh
git commit -m "feat: Claude Code, Codex and Gemini manifests, one merged hooks.json, MCP per host

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Host-neutral skills, `shared/hosts.md` and the rails check

**Files:**
- Create: `shared/hosts.md`, `shared/rails-check.md`
- Modify: `tests/lint-skills.sh`
- Modify: `skills/ticket/SKILL.md`, `skills/bugfix/SKILL.md`, `skills/android-ship/SKILL.md`, `skills/android-commit-push/SKILL.md`, `skills/android-onboard/SKILL.md`, `skills/android-onboard/reference.md`, `skills/android-plan/SKILL.md`, `skills/android-plan/reference.md`, `skills/android-commit-push/reference.md`, `skills/android-develop/SKILL.md`, `skills/android-develop/reference.md`, `skills/android-dist-note/SKILL.md`, `skills/android-release-notes/SKILL.md`, `skills/android-test/SKILL.md`, `skills/android-security-gate/reference.md`, `shared/config.md`, `shared/ticket-file.md`

**Interfaces:**
- Consumes: the canary contract from Task 5.
- Produces: `shared/hosts.md` rows keyed by host name; `shared/rails-check.md` referenced from four skills.

- [ ] **Step 1: Write the lint checks first**

In `tests/lint-skills.sh`, inside the `for skill in …` loop, after the `description` check, add:

```bash
  # Frontmatter is name and description only: the subset every host reads.
  extra="$(awk 'NR==1{next} /^---$/{exit} /^[A-Za-z_-]+:/{sub(/:.*/,""); print}' "$skill" \
           | grep -vxE 'name|description' || true)"
  [ -z "$extra" ] || note "$rel: frontmatter key(s) other hosts may reject: $(printf '%s' "$extra" | tr '\n' ' ')"
  desc_len="$(sed -n 's/^description: //p' "$skill" | head -1 | wc -c | tr -d ' ')"
  [ "$desc_len" -le 1025 ] || note "$rel: description longer than 1024 characters"
```

After the loop (before the MCP block), add:

```bash
# Skills and shared files are host-neutral; host specifics live in shared/hosts.md only.
while read -r f; do
  rel="${f#"$root"/}"
  [ "$rel" = shared/hosts.md ] && continue
  hit="$(grep -nE 'Copilot|Claude Code|Codex|Gemini' "$f" | head -1 || true)"
  [ -z "$hit" ] || note "$rel:$hit — names a host; use shared/hosts.md"
  slash="$(grep -nE '(^|[ `(])/(android-[a-z-]+|ticket|bugfix)([^a-z-]|$)' "$f" | head -1 || true)"
  [ -z "$slash" ] || note "$rel:$slash — slash-invokes a workflow skill; name it in backticks instead"
done < <(find "$root/skills" "$root/shared" -name '*.md')
for s in ticket bugfix android-ship android-commit-push; do
  grep -q 'shared/rails-check.md' "$root/skills/$s/SKILL.md" || note "skills/$s/SKILL.md: does not run shared/rails-check.md"
done
```

Patterns avoid `\b`, which BSD `grep` on macOS does not reliably support.

Run: `./tests/lint-skills.sh`
Expected: FAIL lines for every file listed under **Files** above (host names in `android-onboard`, `android-plan/reference.md`, `shared/config.md`; slash invocations elsewhere; four missing rails checks).

- [ ] **Step 2: Write `shared/hosts.md`**

Before writing, fetch each source and confirm the command; where a source disagrees with this table, use the source and cite it:
- Claude Code: `https://code.claude.com/docs/en/plugins` and `https://code.claude.com/docs/en/discover-plugins`
- Codex: `https://developers.openai.com/codex/plugins/build/` and `https://learn.chatgpt.com/docs/hooks`
- Gemini: `https://geminicli.com/docs/extensions/reference/` and `https://geminicli.com/docs/hooks/`

```markdown
# Hosts

Everything in this workflow that differs between the tools it runs in. Skills never name a tool;
they point here. Copilot and Claude Code rows are verified on a real install
(`docs/checks/`); Codex and Gemini rows are from their documentation, checked 2026-10-12, and
unverified.

## Running a skill

| Tool | How |
|---|---|
| Copilot | `/ticket TA-1234`, or ask in words |
| Claude Code | `/android-workflow:ticket TA-1234`, or ask in words |
| Codex | `$ticket TA-1234`, or ask in words |
| Gemini | ask in words: "run the ticket skill for TA-1234" |

## Signing in to Jira (the Atlassian MCP server)

| Tool | How |
|---|---|
| Copilot | `/mcp`, choose `atlassian`, sign in with your own Atlassian account |
| Claude Code | `/mcp`, choose `atlassian`, authenticate |
| Codex | `codex mcp login atlassian` |
| Gemini | `/mcp auth atlassian` |

## Updating the plugin

| Tool | How |
|---|---|
| Copilot | `copilot plugin update --all` |
| Claude Code | `claude plugin marketplace update eplayment`, then `claude plugin update android-workflow@eplayment` |
| Codex | `codex plugin marketplace upgrade eplayment` |
| Gemini | `gemini extensions update android-workflow` |

## When the rails check fails

The guard hook is not running. Fix it for your tool, start a new session, and rerun.

| Tool | Fix |
|---|---|
| Copilot | `copilot plugin list` must show `android-workflow`; reinstall it if not |
| Claude Code | `/plugin` must show `android-workflow` enabled; `/hooks` must list its `PreToolUse` hook |
| Codex | hooks are behind a feature flag: add `hooks = true` under `[features]` in `~/.codex/config.toml`. If your organization's `requirements.toml` turns hooks off, this workflow cannot run in Codex |
| Gemini | `gemini extensions list` must show `android-workflow` enabled; hooks must be enabled in your settings per geminicli.com/docs/hooks |
```

For the Gemini "When the rails check fails" row: replace "per geminicli.com/docs/hooks" with the exact setting the page documents for enabling hooks. If the page documents none, write "hooks run by default (geminicli.com/docs/hooks, checked 2026-10-12)".

- [ ] **Step 3: Write `shared/rails-check.md`**

```markdown
# The rails check

The four rails (no commit or push on a protected branch, no force-push, no `versionCode` change, no
staged secret) are enforced by a hook, not by this text. If the tool you run in has not loaded that
hook, the rails are off and nothing says so. This check makes that visible.

1. Run exactly this shell command, on its own, through your shell tool. Do not combine it with
   another command, rephrase it, or explain it away:

       : android-workflow-rails-canary

   `:` does nothing, so the command is harmless if it runs.

2. Read the result:
   - **It was blocked by a hook**, with a reason starting `rails live` or saying the guard hook
     could not load its library → the rails are live. Say nothing and continue.
   - **It ran** → the rails are off. Stop and print:
     *"The workflow's guard hook is not running in this tool, so the rails are off. Nothing will
     be committed or pushed."* Then print the row for your tool from "When the rails check fails"
     in `shared/hosts.md`. Do not continue, and do not offer to commit or push some other way.
   - **Anything else** — you were not allowed to run it, it timed out, you cannot tell what
     happened → treat it as not live and stop the same way. No answer is a no.
```

- [ ] **Step 4: Add the rails check to the four skills**

`skills/ticket/SKILL.md` and `skills/bugfix/SKILL.md`: change `Read \`shared/ticket-file.md\` first.` to

```markdown
Read `shared/ticket-file.md` and `shared/rails-check.md` first, and run the rails check before
anything else. It stops the chain here, before any work, if the rails are off.
```

`skills/android-ship/SKILL.md`: after the "Finding these files" block, add

```markdown
Run the rails check in `shared/rails-check.md` before stage 05. If it stops, nothing below runs.
```

`skills/android-commit-push/SKILL.md`: change the first line to `Read \`shared/config.md\`, \`shared/ticket-file.md\` and \`shared/rails-check.md\`, then \`reference.md\` here.` and insert after step 4, renumbering nothing:

```markdown
4b. **Rails check, after the yes and before staging anything**, per `shared/rails-check.md`. If it
    stops, nothing is staged, committed or pushed, whatever the answer at gate 3 was.
```

- [ ] **Step 5: Make the wording host-neutral**

Slash invocations of workflow skills: in every file under `skills/` and `shared/`, remove the slash and keep the backticks:

```bash
find skills shared -name '*.md' -exec sed -i '' -E 's#`/(android-[a-z-]+|ticket|bugfix)#`\1#g' {} +
```

Then fix by hand the ones without backticks (from `grep -rnE '(^|[ (])/(android-[a-z-]+|ticket|bugfix)([^a-z-]|$)' skills shared`):

| File | Old | New |
|---|---|---|
| `skills/ticket/SKILL.md:3` | `, or types /ticket.` | `, or asks for the ticket workflow by name.` |
| `skills/ticket/SKILL.md:6` | `# /ticket — the feature workflow` | `# ticket — the feature workflow` |
| `skills/bugfix/SKILL.md:3` | `, or types /bugfix.` | `, or asks for the bugfix workflow by name.` |
| `skills/bugfix/SKILL.md:6` | `# /bugfix — the bugfix workflow` | `# bugfix — the bugfix workflow` |
| `skills/android-commit-push/reference.md:50,60` | `run /android-review to see them` | ``run `android-review` to see them`` |
| `skills/android-onboard/reference.md:119` | `written by /android-onboard` | ``written by `android-onboard` `` |
| `skills/android-plan/reference.md:104` | `Rerun /android-plan TA-1234` | ``Rerun `android-plan` for TA-1234`` |
| `skills/android-plan/reference.md:114` | `/android-plan <KEY>."` | `` `android-plan` <KEY>."`` |

Host names and host commands:

| File | Old | New |
|---|---|---|
| `skills/android-onboard/SKILL.md:3` | `for the Copilot Android workflow` | `for the Android workflow` |
| `skills/android-plan/reference.md:31` | `Fix: run /mcp in Copilot, sign in to the Atlassian server with your own account, then rerun.` | `Fix: sign in to the Atlassian MCP server with your own account (how, for your tool: "Signing in to Jira" in shared/hosts.md), then rerun.` |
| `skills/android-onboard/reference.md:102` | `with the fix: "run \`/mcp\` and sign in".` | `with the fix: "sign in — see 'Signing in to Jira' in \`shared/hosts.md\`".` |
| `shared/config.md:116` | ``run `copilot plugin update` `` | ``update the plugin ("Updating the plugin" in `shared/hosts.md`)`` |
| `skills/android-security-gate/reference.md:58` | `` the CLI's `/security-review` `` | `` a built-in `/security-review` command `` |

`/security-review` and `/pr` stay: they are tool commands named conditionally, not workflow skills, and the lint rule does not match them.

- [ ] **Step 6: Lint and test**

Run: `./tests/lint-skills.sh && ./tests/run.sh | tail -1 && git diff --stat`
Expected: `skill lint: OK`; `0 failed`; the diff touches only the files listed under **Files**. Read the full `git diff -- skills shared` once and fix any sentence the slash removal left ungrammatical.

- [ ] **Step 7: Commit**

```bash
git add shared skills tests/lint-skills.sh
git commit -m "feat: host-neutral skills, shared/hosts.md, and the rails check before any commit

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Live verification on Claude Code and Copilot

**Files:**
- Modify: `docs/checks/2026-10-12-claude-code-checks.md`
- Create: `docs/checks/host-checklist.md`

**Interfaces:**
- Consumes: everything from Tasks 3–8.

- [ ] **Step 1: Claude Code, in a fixture repository**

```bash
FX="$("$PLUGIN/tests/fixtures/new-repo.sh" on-feature)"; cd "$FX"
claude -p --plugin-dir "$PLUGIN" --allowedTools Bash Edit \
  "Do these four things one at a time and report exactly what happened to each, including any hook message:
   1. Run the shell command: : android-workflow-rails-canary
   2. Run the shell command: git push origin develop
   3. Edit app/build.gradle to change versionCode 60 to versionCode 61.
   4. Run the shell command: git status" 2>&1 | tee "$SCRATCH/live-claude.txt" | tail -30
grep -c 'versionCode 60' app/build.gradle
```

Expected: 1 blocked with `rails live`; 2 blocked with `protected`; 3 blocked with `versionCode`; 4 ran. `grep -c` prints `1` (the file is unchanged).

- [ ] **Step 2: Claude Code, skill discovery and a skill-to-skill call**

```bash
cd "$FX" && claude -p --plugin-dir "$PLUGIN" "List the android-workflow plugin skills you can run, by name only." 2>&1 | tail -20
cd "$FX" && claude -p --plugin-dir "$PLUGIN" --allowedTools Bash \
  "Run the android-ship skill. Stop after its rails check and tell me its result; do not run stage 05." 2>&1 | tail -20
```

Expected: the list has all 14 skills; the second run reports the rails check as live (the canary was blocked). Then `rm -rf "$FX"`.

- [ ] **Step 3: Copilot re-run on 1.0.89**

```bash
FX="$("$PLUGIN/tests/fixtures/new-repo.sh" on-feature)"; cd "$FX"
copilot --plugin-dir "$PLUGIN" --allow-all-tools --no-ask-user \
  -p "Run the shell command ': android-workflow-rails-canary', then 'git push origin develop'. Report exactly what happened to each." 2>&1 | tail -20
rm -rf "$FX"
```

Expected: both denied by the preToolUse hook, with `rails live` and `protected`.

- [ ] **Step 4: Record**

Under `## Live verification` in `docs/checks/2026-10-12-claude-code-checks.md`, replace "Recorded in Task 9." with a table of the checks in Steps 1–3 (host, version, check, result) and the relevant output lines. Any failure: stop and report it to the user before Task 10 — do not adjust the expectation to the result.

- [ ] **Step 5: Write `docs/checks/host-checklist.md`**

```markdown
# Host checklist — Codex and Gemini

Codex and Gemini support is built from their documentation and is **unverified**. Run this on an
install your organization has approved for company work (`.ai/company/ai-usage-policy.md`), in a
scratch repository from `tests/fixtures/new-repo.sh on-feature`, never in a real app repository.
Record the result in a new `docs/checks/<date>-<tool>-checks.md`, and change the tool's row in the
README's "Supported surfaces" from unverified to verified only if every check passes.

## Install

| Tool | Install |
|---|---|
| Codex | `codex plugin marketplace add eric-cerio/eplayment-ai-workflow`, then install `android-workflow` from the marketplace; turn hooks on (`shared/hosts.md`) |
| Gemini | `gemini extensions install https://github.com/eric-cerio/eplayment-ai-workflow` |

## Checks

| # | Ask the tool to | Pass when |
|---|---|---|
| 1 | load the plugin, with no error mentioning `hooks.json`, `PreToolUse` or `BeforeTool` | the tool's startup or debug log is clean |
| 2 | run `: android-workflow-rails-canary` | blocked, reason starts `rails live` |
| 3 | run `git push origin develop` | blocked, reason mentions `protected` |
| 4 | change `versionCode 60` to `versionCode 61` in `app/build.gradle` with its own edit tool | blocked; the file still says `versionCode 60` |
| 5 | change `versionName "3.4.27"` to `"3.4.28"` the same way | allowed |
| 6 | list the `android-workflow` skills | all 14 listed |
| 7 | run the `android-ship` skill and stop after its rails check | reports the rails as live |
| 8 | sign in to the Atlassian MCP server ("Signing in to Jira" in `shared/hosts.md`) | the server shows as connected |
```

- [ ] **Step 6: Commit**

```bash
cd "$PLUGIN" && git add docs/checks
git commit -m "docs: Claude Code and Copilot live checks; the checklist for Codex and Gemini

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: README and version 0.3.0

**Files:**
- Modify: `README.md`, `plugin.json`, `.claude-plugin/plugin.json`, `gemini-extension.json`

- [ ] **Step 1: Bump the version, lint first**

Set `"version": "0.3.0"` in `plugin.json` only, then run `./tests/lint-skills.sh`.
Expected: FAIL — `.claude-plugin/plugin.json` and `gemini-extension.json` versions differ. Set both to `0.3.0`; rerun; expected `skill lint: OK`.

Also update `plugin.json`'s `description`: replace `for Copilot: ` with `: ` so it no longer names one host.

- [ ] **Step 2: Rewrite the README's top, install and surfaces sections**

- First paragraph: `The Eplayment Android development workflow, as a plugin for GitHub Copilot, Claude Code, Codex and Gemini.` (rest of the paragraph unchanged).
- `## Install` becomes one subsection per tool:

```markdown
## Install

Installing needs GitHub access to this repository.

### Copilot
    copilot plugin install eric-cerio/eplayment-ai-workflow
    copilot plugin update --all        # later, to pick up changes

### Claude Code
    claude plugin marketplace add eric-cerio/eplayment-ai-workflow
    claude plugin install android-workflow@eplayment

### Codex — unverified
    codex plugin marketplace add eric-cerio/eplayment-ai-workflow
Then install `android-workflow` from the `eplayment` marketplace, and turn hooks on: add
`hooks = true` under `[features]` in `~/.codex/config.toml`.

### Gemini — unverified
    gemini extensions install https://github.com/eric-cerio/eplayment-ai-workflow

**Codex and Gemini need approval before company use.** Under the AI usage policy, a tool not
approved for company work cannot be used on company code or Jira data. This plugin supporting a
tool does not approve it; ask before installing it for real work.
```

  Keep the existing `GITHUB_TOKEN` paragraph under Copilot, and the "Then, once per repository" `android-onboard` paragraph after the subsections, with "`/android-onboard`" changed to "the `android-onboard` skill (how to run a skill in your tool: `shared/hosts.md`)".

- `### Jira`: replace "Sign in once with your own Atlassian account when Copilot asks; `/mcp` shows whether it is connected." with "Sign in once with your own Atlassian account — `shared/hosts.md` has the command for each tool." Replace "The server is declared in every Copilot session" with "The server is declared in every session of every tool".
- `## Supported surfaces`: a table, then the existing Copilot and Android Studio paragraphs:

```markdown
| Tool | Version | Status |
|---|---|---|
| Copilot CLI | 1.0.89 | verified — `docs/checks/2026-09-20-platform-checks.md`, re-run in `docs/checks/2026-10-12-claude-code-checks.md` |
| Claude Code | 2.1.288 | verified — `docs/checks/2026-10-12-claude-code-checks.md` |
| Codex CLI | — | built from documentation, **unverified** — `docs/checks/host-checklist.md` |
| Gemini CLI | — | built from documentation, **unverified** — `docs/checks/host-checklist.md` |
| Android Studio (Copilot plugin) | 1.11.0 | partly verified (below) |
```

- `## The skills`: change the column header to `Skill`, drop the leading `/` from every skill in the table, and add one line above it: "How to run a skill differs by tool — see `shared/hosts.md`."
- `## Picking up where you left off`: `/ticket TA-1234` → "the `ticket` skill for TA-1234"; `/android-commit-push` → "`android-commit-push`".
- `## The rails`: change "A `preToolUse` hook denies these" to "A hook denies these, on every supported tool,". Add after the list:

```markdown
**The rails check.** A hook that a tool silently fails to load would leave the rails off with
nothing saying so. So `ticket`, `bugfix`, `android-ship` and `android-commit-push` first run a
harmless command the hook always blocks; if it is not blocked, they stop before any work and before
anything is staged. It proves the shell hook runs. The `versionCode` rail on file edits depends on
the edit-tool names in `hooks/hooks.json`, which lint checks against each tool's documentation.
```

- `## Developing`: add `claude --plugin-dir "$PWD"` next to the Copilot line; change the `./tests/run.sh` comment to `# every hook case on Copilot, Claude Code, Codex and Gemini payloads, fail-closed, fingerprint` and the lint comment to add `manifests, hooks.json matchers, host-neutral skills`. Change "Hooks live at `com.github.copilot/hooks/hooks.json` — a plugin declaring…" to:

```markdown
Hooks are wired twice: `com.github.copilot/hooks/hooks.json` for Copilot (a plugin declaring the
Agent Plugins v1 `$schema` is not read from anywhere else), and `hooks/hooks.json` for Claude Code,
Codex and Gemini, which all read that one path — so it carries both the `PreToolUse` and the
`BeforeTool` keys. Every host's payload goes through `hooks/codec.sh`.
```

- [ ] **Step 3: Check nothing stale remains**

Run: `grep -nE '/android-|/ticket|/bugfix|21 hook cases' README.md`
Expected: no output, except inside the Running-a-skill hint if you quoted a Copilot example there (there should be none; the examples live in `shared/hosts.md`).

- [ ] **Step 4: Final run**

Run: `./tests/lint-skills.sh && ./tests/run.sh | tail -1 && claude plugin validate "$PLUGIN"`
Expected: `skill lint: OK`, `0 failed`, validate passes.

- [ ] **Step 5: Commit**

```bash
git add README.md plugin.json .claude-plugin/plugin.json gemini-extension.json
git commit -m "chore: 0.3.0 — one plugin for Copilot, Claude Code, Codex and Gemini

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

Do not push or tag. Report to the user that the branch is ready, with the test totals and the Task 9 results.
