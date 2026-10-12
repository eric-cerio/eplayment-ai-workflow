# Claude Code platform checks — 2026-10-12

Run against Claude Code **2.1.296** on macOS 26.4.1 (Darwin 25.4.0), with a throwaway plugin (`probe`, two skills, one
`hooks/hooks.json` holding both a Claude Code `PreToolUse` entry and a Gemini `BeforeTool` entry).
The hook script logs every payload to `payload.log` and exits 2 when the payload contains `probe-deny`.

| # | Check | Result |
|---|---|---|
| a | Claude Code loads a `hooks/hooks.json` that also holds `BeforeTool` keys | **Pass with warning** — `PreToolUse` loads and fires; `claude plugin validate` warns `hooks.BeforeTool: unknown hook event; entry ignored at runtime` (exit 0) |
| b | `${CLAUDE_PLUGIN_ROOT:-$PLUGIN_ROOT}` resolves in a hook command | **Pass** — `log.sh` ran and wrote `payload.log` |
| c | Exit 2 + stderr denies a Bash call | **Pass** — `echo probe-deny` was blocked with "probe denied by hook" |
| d | Payload field names | Recorded below |
| e | One plugin skill can invoke another | **Pass** — `probe-a` ran `probe-b`, output contained `PROBE-B-RAN` |

## a. Merged hooks.json — validator warns

```
Validating hooks: .../probe-plugin/hooks/hooks.json

⚠ Found 1 warning:

  ❯ hooks: hooks.BeforeTool: unknown hook event; entry ignored at runtime

✔ Validation passed with warnings
```

Validation passes (exit 0). The warning says the unknown entry is "ignored at runtime", and the
`PreToolUse` entry in the same file loaded and fired (b, c). The task's literal rule treated any warning
naming `BeforeTool` as a fail; the controller ruled that spec 5.1's fallback applies only if Claude Code
*rejects* `BeforeTool`, which it does not.
The other warning in the same validate output was the missing `author` field in `plugin.json`.

**Decision.** The warning is accepted because Claude Code ignores, rather than rejects, Gemini's keys.
The plan proceeds. If a future Claude Code rejects unknown events, the rails canary makes it a visible
stop and the gemini-branch fallback is needed.

## b, c, d. Hook run

The probe hook ran for both Bash calls. `echo probe-allow` ran and printed. `echo probe-deny` was blocked;
the agent reported:

```
PreToolUse:Bash hook error: ["${CLAUDE_PLUGIN_ROOT:-$PLUGIN_ROOT}/hooks/log.sh"]: probe denied by hook
```

The error text echoes the command as configured (unexpanded), but the script did execute: `payload.log`
exists and holds two lines, and the stderr text came from `log.sh`. `payload.log` lists the deny call first, then the allow call.

### The payload shape (d)

```json
{"session_id":"d04fef62-…","transcript_path":"/Users/…/d04fef62-….jsonl",
 "cwd":"/private/tmp/…/scratchpad","prompt_id":"576a3e38-…","permission_mode":"default",
 "effort":{"level":"medium"},"hook_event_name":"PreToolUse","tool_name":"Bash",
 "tool_input":{"command":"echo probe-allow","description":"Print probe-allow marker"},
 "tool_use_id":"toolu_014U…"}
```

- The shell tool is **`Bash`** (capitalised); the command is at **`tool_input.command`**; `cwd` is top level.
- `tool_input` is a nested object, not an escaped string.
- Field names are snake_case (`tool_name`, `tool_input`, `hook_event_name`), unlike Copilot's `toolName`/`toolArgs`.

## e. Skill to skill

`claude -p --plugin-dir "$P" "Run the probe-a skill."` printed `PROBE-B-RAN` and
"The probe-a skill ran and called probe-b, and probe-b printed the marker above."

## Commands run

`$P=$SCRATCH/probe-plugin`; the plugin files are the ones in the Task 1 brief, verbatim.

```bash
claude --version
claude plugin validate "$P"
# (every command ran from `cd "$SCRATCH"`, the session scratchpad; `$P` as above)
# first attempt failed: `--allowedTools Bash --debug "<prompt>"` — both flags take a variadic/optional
# value and swallowed the prompt ("Input must be provided either through stdin or as a prompt argument").
# Flag problem, unrelated to the probe. NOT run verbatim from the brief: the rerun delivers the prompt on
# stdin instead of as an argument and uses --allowedTools=Bash:
echo "Run the shell command: echo probe-allow. Then run the shell command: echo probe-deny. Report exactly what happened to each." \
  | claude -p --plugin-dir "$P" --allowedTools=Bash --debug > "$SCRATCH/probe-run.txt" 2>&1
cat "$P/payload.log"
claude -p --plugin-dir "$P" "Run the probe-a skill." 2>&1 | tail -20
```

`--plugin-dir` is a recognised flag; no substitute was needed. `--debug` output did not land in
`probe-run.txt`, so the debug log was not available as extra evidence.

## Live verification

Run 2026-10-12 against the working copy (`--plugin-dir`), each in a throwaway fixture from
`tests/fixtures/new-repo.sh on-feature` (no remote, deleted afterwards). Claude Code 2.1.296; Copilot CLI 1.0.89.
Raw outputs were kept in the session scratchpad.

| # | Host | Version | Check | Result |
|---|---|---|---|---|
| 1 | Claude Code | 2.1.296 | canary `: android-workflow-rails-canary` | **Pass** — blocked: `PreToolUse:Bash hook error: rails live: the android-workflow guard hook is running.` |
| 2 | Claude Code | 2.1.296 | `git push origin develop` | **Pass** — blocked: `Blocked: 'develop' is protected. Push your working branch instead (feature/<KEY> or bugfix/<name>).` |
| 3 | Claude Code | 2.1.296 | Edit `versionCode 60` to `61` | **Pass** — blocked: `PreToolUse:Edit hook error: Blocked: versionCode is owned by CI and release, never by this workflow.`; `grep -c 'versionCode 60' app/build.gradle` printed `1` |
| 4 | Claude Code | 2.1.296 | `git status` | **Pass** — ran, `nothing to commit, working tree clean` |
| 5 | Claude Code | 2.1.296 | skill discovery | **Pass** — 14 skills listed: android-branch, android-commit-push, android-develop, android-dist-note, android-lint, android-onboard, android-plan, android-release-notes, android-review, android-security-gate, android-ship, android-test, bugfix, ticket |
| 6 | Claude Code | 2.1.296 | `android-ship` stops after rails check | **Pass on rerun** — see note; reported `The rails check passed: the rails are live` (canary blocked with `rails live: ...`), ticket TA-1234, stage 05 not run |
| 7 | Copilot CLI | 1.0.89 | canary | **Pass** — `Denied by preToolUse hook: rails live: the android-workflow guard hook is running.` |
| 8 | Copilot CLI | 1.0.89 | `git push origin develop` | **Pass** — `Denied by preToolUse hook: Blocked: 'develop' is protected. Push your working branch instead (feature/<KEY> or bugfix/<name>).` |

Notes:

- Commands used `--allowedTools=Bash,Edit` (with `=`) and the prompt on stdin, per Task 1's finding.
- Check 6, first run: `claude -p ... --allowedTools=Bash` stopped before the rails check, because reading
  `shared/ticket-file.md` and `shared/rails-check.md` from the plugin folder was refused (the folder is outside
  the fixture's working directory and was not allowed in that headless session). This was a permission
  setup problem, not a hook or skill failure. Rerun with `--add-dir "$PLUGIN" --allowedTools=Bash,Read`
  passed. In a real install the plugin folder may need the same read access in headless mode.
- `claude plugin validate` still warns that `BeforeTool`/`AfterTool` are ignored at runtime (accepted, controller
  Ruling 3). No other startup error was seen in the command output; `--debug` was not used, so the debug log was
  not inspected.
- No command in the Copilot or Claude Code rows of `shared/hosts.md` was contradicted by these runs (only the hook
  behaviour and skill list were exercised).
