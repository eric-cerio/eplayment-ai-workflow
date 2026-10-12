# Multi-host portability — design

**Status:** approved design, not yet built
**Date:** 2026-10-12
**Amends:** `2026-09-20-android-copilot-workflow-design.md` — packaging, hooks and install. The
stages, gates, ticket file and rail semantics there stand unchanged.

## 1. What this adds

The plugin runs today on GitHub Copilot only. This makes the same repository install and run on
**Claude Code, Codex CLI and Gemini CLI** as well, with the same skills, the same Jira MCP server
and the **same four rails, enforced by a hook** on every host.

## 2. Why

The team uses mixed tools. A developer on Claude Code or Codex should get the same workflow and the
same safety as one on Copilot, without a second copy of the skills to keep in step.

## 3. Decisions

| Topic | Decision |
|---|---|
| Hosts in this version | Copilot (existing), Claude Code, Codex CLI, Gemini CLI |
| Rails | Hook-enforced on every supported host. A host that cannot deny a tool call before it runs is not supported |
| Packaging | One repository, one rails engine. Copilot and Codex share the root `plugin.json`; Claude Code and Gemini get their own manifest. No build step |
| Verification | Copilot and Claude Code verified on a real install. Codex and Gemini built from their documentation and marked **unverified** until someone runs the checks |
| Silent hook failure | A canary command the hook always denies; the chains and the commit stage stop if it runs |
| Out of scope | Cursor; Android Studio plugin verification (unchanged); Gemini custom-command TOML files |

## 4. Host facts this design relies on

Sourced from each host's documentation on 2026-10-03 (Codex: learn.chatgpt.com/docs/hooks;
Gemini: geminicli.com/docs/hooks/reference and /docs/extensions/reference) and, for Copilot, from
`docs/checks/2026-09-20-platform-checks.md`.

| | Hook config | Event | Shell tool → command field | Edit tools | Deny | Plugin root |
|---|---|---|---|---|---|---|
| Copilot | `com.github.copilot/hooks/hooks.json` | `preToolUse` | `bash` → `toolArgs.command` | `edit`, `create`, `str_replace_editor`, `apply_patch`, `write` | `{"permissionDecision":"deny",…}`, exit 0 | relative path |
| Claude Code | `hooks/hooks.json` | `PreToolUse` | `Bash` → `tool_input.command` | `Edit`, `Write`, `MultiEdit` (`tool_input.file_path`) | `hookSpecificOutput.permissionDecision`, or exit 2 + stderr | `${CLAUDE_PLUGIN_ROOT}` |
| Codex | `hooks/hooks.json` | `PreToolUse` | `Bash` → `tool_input.command` | `apply_patch` (patch text in `tool_input.command`), aliases `Edit`, `Write` | as Claude Code; or exit 2 + stderr | `PLUGIN_ROOT` (also `CLAUDE_PLUGIN_ROOT`) |
| Gemini | `hooks/hooks.json` | `BeforeTool` | `run_shell_command` → `tool_input.command` | `write_file`, `replace` (`tool_input.file_path`) | `{"decision":"deny","reason":…}`, or exit 2 + stderr | `${extensionPath}` |

Codex hooks sit behind the `hooks` feature flag (`[features]` in `~/.codex/config.toml`), which a
user or admin can turn off. Section 6 exists because of that.

## 5. Layout and hook wiring

```
plugin.json                          Copilot and Codex manifest (Agent Plugins v1, unchanged)
.claude-plugin/plugin.json           Claude Code manifest
.claude-plugin/marketplace.json      Claude Code marketplace: one plugin, source "./"
.agents/plugins/marketplace.json     Codex marketplace: one plugin, source path "./"
gemini-extension.json                Gemini manifest: mcpServers (atlassian)
mcp.json                             Copilot and Codex MCP (unchanged)
.mcp.json                            Claude Code MCP
com.github.copilot/hooks/hooks.json  Copilot hooks (unchanged)
hooks/hooks.json                     Claude Code, Codex and Gemini hooks — one merged file
hooks/guard-rails.sh                 the rails (unchanged logic)
hooks/post-edit.sh                   advisory post-edit checks
hooks/lib.sh                         helpers
hooks/codec.sh                       NEW: host detection, payload decoding, reply encoding
skills/, shared/                     unchanged location
```

Codex reads the root `plugin.json` (Agent Plugins v1) and `mcp.json`, the files Copilot already
uses; a `.codex-plugin/` manifest is only Codex's fallback, so none is added (Codex plugin docs,
developers.openai.com/codex/plugins/build, 2026-10-12). The three manifests carry the same `name`
(`android-workflow`), `version` and `description`.

### 5.1 One `hooks/hooks.json` for three hosts

Claude Code, Codex and Gemini all load `hooks/hooks.json` from the plugin root, so the file cannot
be split. It holds two sets of keys:

- `PreToolUse` / `PostToolUse`, read by Claude Code and Codex, which share the format:
  matcher `Bash|Edit|Write|MultiEdit|apply_patch`, command
  `"${CLAUDE_PLUGIN_ROOT:-$PLUGIN_ROOT}/hooks/guard-rails.sh"` (and `post-edit.sh`).
- `BeforeTool` / `AfterTool`, read by Gemini: matcher `run_shell_command|write_file|replace`,
  command `"${extensionPath}/hooks/guard-rails.sh" --host gemini` (and `post-edit.sh`).

**Risk:** each host must ignore the other's event keys. Claude Code is tested on a real install as
the first task of the plan. If Claude Code rejects `BeforeTool`, Gemini is installed from a
generated `gemini` branch whose `hooks/hooks.json` has only the Gemini keys; that branch is the
only build step this design allows. Codex and Gemini tolerance is unverified (section 8.3).

### 5.2 The codec

`hooks/codec.sh`, sourced by both hook scripts after `lib.sh`, does three things.

**Detect the host.** `--host <name>` when given; otherwise from the payload: `toolName` with
`toolArgs` → `copilot`; `tool_name` with `tool_input` → `claude` (Claude Code and Codex share every
field the rails read and the deny format, so they are one codec). Anything else → `unknown`.

**Decode** into the fields the rails already use:

| Field | Meaning |
|---|---|
| `kind` | `shell`, `edit` or `other` |
| `cmd` | the shell command (`shell` only) |
| `path` | the edited file (`edit` only); for `apply_patch`, every path named on a `*** Add File:` or `*** Update File:` line |
| `new_text` | the text being written: `new_str`, `new_string`, `content`, or the `+` lines of a patch |

Tool names map to `kind` per the table in section 4. The `versionCode` edit rail tests `new_text`
for `edit` on a `.gradle` / `.gradle.kts` path, and for `apply_patch` each path in the patch.

**Encode** the decision:

- **Allow:** `{}` on stdout, exit 0, on every host.
- **Deny, Copilot:** `{"permissionDecision":"deny","permissionDecisionReason":…}` on stdout, exit 0
  — the verified behavior, unchanged.
- **Deny, Claude Code / Codex:** the reason on stderr and exit 2. The `hookSpecificOutput` JSON is
  also written to stdout; it is ignored on exit 2 and is there for a host that reads stdout only.
- **Deny, Gemini:** the reason on stderr and exit 2; `{"decision":"deny","reason":…}` on stdout.
- **Unknown host:** a git write is denied in all of the forms above at once (Copilot JSON on
  stdout, reason on stderr, exit 2); everything else is allowed. A shape the codec does not
  recognize must not open a hole in the rails.

The fail-closed path in `guard-rails.sh` that runs before `lib.sh` loads uses the same rule: with no
codec available it denies git writes and the canary in every form at once.

`post-edit.sh` writes its advisory output as `additionalContext` (Copilot),
`hookSpecificOutput.additionalContext` (Claude Code / Codex) or `systemMessage` (Gemini). It never
blocks; a host that ignores the output loses only the hint.

## 6. The rails canary

A rail that is present in the file and absent at runtime is the failure this plugin has already
had once. On Codex the hooks flag can be off; on Codex and Gemini the hook wiring is unverified.
The canary turns either into a visible stop.

- The canary is the command `: android-workflow-rails-canary`. `:` is the shell no-op, so if it
  runs, nothing happens.
- `guard-rails.sh` denies any command containing `android-workflow-rails-canary`, **before** the
  configured-repository check and also on the library-failed path. The deny reason is
  `rails live`.
- New `shared/rails-check.md` defines the step:
  - **Denied** → the rails are live; continue.
  - **Ran** → stop and print: *"The workflow's guard hook is not running in this tool, so the
    rails are off. Nothing will be committed or pushed."*, followed by the host's fix from
    `shared/hosts.md`.
  - **Anything else** (refused for another reason, no result) → treated as not live. No answer at a
    gate is a no, as elsewhere in this workflow.
- It runs at the start of `ticket`, `bugfix` and `android-ship`, and immediately before the commit
  in `android-commit-push`. Stages that do not write to git do not run it.

**Limit, stated in the README:** the canary proves the shell hook fires. The edit rail
(`versionCode`) depends on the edit matchers in `hooks/hooks.json`, which lint checks against each
host's documented tool names.

## 7. Skills, MCP and host differences

### 7.1 Skills

- Skills stay in `skills/<name>/SKILL.md` with `name` and `description` frontmatter only.
- Skill-to-skill calls are worded host-neutrally: "run the `android-ship` skill", not
  `/android-ship`. Every skill file is updated.
- The plugin-root lookup ("the nearest ancestor containing `plugin.json`") is kept: every host
  installs the whole repository and the Copilot `plugin.json` stays at its root.
- No skill text names a host. Host-specific commands live in `shared/hosts.md` only.

### 7.2 `shared/hosts.md`

One table, one row per host: how to run a skill, how to sign in to the Atlassian MCP server, how to
update the plugin, how to enable hooks, and how to check that the plugin's hooks are loaded. Each
command cites the documentation page it was taken from; the Copilot and Claude Code rows are run
during verification.

The three places that name Copilot today point to it instead: the `/mcp` sign-in hint in
`skills/android-plan/reference.md`, the update hint in `shared/config.md`, and the
`android-onboard` description.

### 7.3 MCP

The same Atlassian server (`https://mcp.atlassian.com/v1/mcp`), declared once per host format:
`mcp.json` (Copilot, Codex), `.mcp.json` (Claude Code), both `"type":"http","url"`, and
`gemini-extension.json` (`"httpUrl"`). No token in any file; each developer signs in with their own
account; read-only, as now.

## 8. Testing

### 8.1 `tests/run.sh`

- Cases become host-neutral. A case gives `kind`, `cmd` or `path` + `new_text`, plus the existing
  `expect`, `match` and `fixture` headers; `tests/payloads/<host>.sh` renders it into each host's
  payload. Every case runs once per host: Copilot, Claude Code, Codex (with `apply_patch` for
  edits) and Gemini.
- The runner checks the host's deny form: Copilot — `"deny"` on stdout, exit 0; Claude Code, Codex
  and Gemini — exit 2 with the match on stderr.
- New cases:
  - the canary is denied on every host, outside a configured repository, and with `lib.sh`
    unreadable
  - an `apply_patch` that changes `versionCode` in `app/build.gradle` is denied
  - a Gemini `replace` on `versionCode` is denied
  - an unknown payload shape denies `git push` and allows `ls`
- The existing fail-closed and fingerprint checks stay.

### 8.2 `tests/lint-skills.sh`

Adds:

- the three manifests and both marketplace entries share `name`, and the manifests share `version`
- `hooks/hooks.json` matchers include each host's shell and edit tool names from section 4
- every command in either `hooks.json` points to an executable file in the repository
- no manifest or MCP file contains a credential-shaped value
- skill `name` matches its directory, `description` is at most 1024 characters, no other
  frontmatter keys
- no skill file names a host or a host-specific slash command

### 8.3 Verification on real installs

- **Copilot:** re-run on the installed 1.0.89: hooks fire and deny, the canary is denied.
- **Claude Code:** install from the repository; record in
  `docs/checks/2026-10-12-claude-code-checks.md` that the merged `hooks/hooks.json` loads, the
  canary is denied, a push to `develop` is denied, an `Edit` of `versionCode` is denied, and one
  skill calls another.
- **Codex, Gemini:** not installed here. The same checklist is written into
  `docs/checks/host-checklist.md` for whoever has an approved install.

## 9. Docs and release

- README: one install subsection per host; a "Supported surfaces" table with each host's
  verification status (Copilot and Claude Code verified; Codex and Gemini *built from docs,
  unverified*); the canary and its limit.
- README policy line: using Codex or Gemini on company work requires approval under the AI usage
  policy. This plugin supporting a tool does not approve it.
- Version `0.3.0` in all three manifests. Run both test scripts before tagging, as now.
