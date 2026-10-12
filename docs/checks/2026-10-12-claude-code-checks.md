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

Recorded in Task 9.
