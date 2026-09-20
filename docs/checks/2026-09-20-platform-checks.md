# Copilot platform checks — 2026-09-20

Run against Copilot CLI **1.0.85** on macOS 25.4, with a throwaway plugin at `/tmp/hello-plugin`
(two skills, one `preToolUse` hook that logs every payload and denies `git push`).

| # | Check | Result |
|---|---|---|
| 1 | Skills reach Android Studio | **Partly** — repo skills load (asked in words, no slash command); a plugin install can only be tested after publishing |
| 2 | Hooks fire in the CLI and can deny | **Pass**, after moving `hooks.json` (see below) |
| 3 | One skill can call another | **Pass** |
| 4 | A skill can read a sibling skill's file | **Pass** |
| 5 | Writes inside `.git/` are allowed | **Pass** |
| 6 | A draft PR without `gh` | **No** — `gh` is the only path, and it is installed here |

## 1. Android Studio — partly answered, 2026-09-21

**Skills reach Android Studio through the repository, not by slash command.** With
`.github/skills/hello-android/SKILL.md` in the open project, the IDE agent loaded the skill and
produced exactly its steps — but only when asked in plain words ("run the hello-android skill").
`/hello-android` was not offered as a slash command. The same skill is listed by the CLI under
"Project skills".

**Whether a plugin reaches Android Studio is still unproven**, and two attempts to test it failed
for reasons of method, not capability:

- Copying a plugin folder into `~/.copilot/installed-plugins/local/` does **not** install it:
  `copilot plugin list` ignores it, and so did the IDE. Installation is recorded elsewhere.
- `copilot plugin install` accepts only `plugin@marketplace`, `owner/repo`, or a URL. A
  `file://` URL to a local bare repo is rejected: "Invalid plugin spec". **So a properly installed
  plugin cannot be tested until this repository is published to GitHub** (plan Task 16).

The IDE's own policy allows all of it — `CustomAgent: true, CustomHook: true, CustomSkill: true`
(`idea.log`, `CopilotPolicyServiceImpl`).

**Repo-level hooks were also a bad test.** `.github/hooks/hooks.json` fired nothing in Android
Studio *or* the CLI, so it proves nothing about the IDE. The SDK does resolve a repo hooks
directory at `join(gitRoot, ".github", "hooks")`, but it sits behind a `POLICY_HOOKS` feature flag
and the file convention inside it is not `hooks.json`. The design does not need it: hooks ship with
the plugin, where they are verified working.

**Consequence for the plan.** Check 1 is answered at publish time (Task 16), not before. Until
then the rails are CLI-verified only, which matches the decision already taken: if plugin skills
do not reach Android Studio, v1 is CLI-only, run from the IDE's terminal.

## 2. Hooks — the path in the docs was wrong

The first run produced **no hook log at all**. The CLI log said why:

```
[ERROR] [rust:hooks] Plugin "hello-android" declares the Agent Plugins v1 $schema, so its hooks are
read only from "com.github.copilot/hooks/hooks.json". "hooks/hooks.json" at the plugin root is no
longer read; move it there.
```

**A plugin whose `plugin.json` declares `$schema: https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`
must put its hooks at `com.github.copilot/hooks/hooks.json`.** The hook script itself can stay at
`hooks/`, because the `bash` value resolves relative to the plugin root.

After the move, the hook fired on every tool call, and the deny worked:

```
✗ Push develop branch to origin (shell)
  │ git push origin develop
  └ Denied by preToolUse hook: hello-plugin check: push blocked
```

The agent reported it could not override the block.

### The payload shape is not what the plan assumed

```json
{"sessionId":"3a31…","timestamp":1789918821360,"cwd":"/Users/…/ai-workflow",
 "toolName":"bash",
 "toolArgs":{"command":"cat … | grep '^name:'","description":"Read sibling skill name line"}}
```

Two corrections for the guard-rails hook:

- **`toolArgs` is a nested JSON object, not an escaped JSON string.** No unescaping step is needed;
  read the fields straight out of the payload.
- **The shell tool is named `bash`.** Other names seen: `skill`, `view`. The file-editing names
  (`edit`, `create`, `str_replace_editor`, `apply_patch`) come from the SDK and still need
  confirming from a real edit.

## 3, 4, 5. Skills — all three pass

One run of `/hello-caller` covered all three:

- It invoked `skill(hello-caller)`, which invoked `skill(hello-android)`, which ran to completion
  and printed `CALLER-OK` — **a skill can call another skill**, so the chains can invoke stage
  skills directly.
- It read `../hello-caller/SKILL.md` relative to its own folder and printed `name: hello-caller` —
  **sibling file reads work**, so `shared/config.md` and `shared/ticket-file.md` are reachable.
- It created `<git-common-dir>/android-workflow/check.txt` — **writing inside `.git/` is allowed**,
  so the ticket file stays where the spec puts it. No `.gitignore` fallback needed.

## 6. The draft PR needs `gh`, and `gh` is here

Asked to open a draft PR, the agent used `git`, then `gh auth status`, and named its intended
command:

```
git push -u origin feature/TA-1
gh pr create --base develop --head feature/TA-1 --draft --fill
```

There is no built-in PR tool it can call: `/pr` is a CLI slash command a person types, not something
a skill can invoke.

**`gh` 2.92.0 is installed on this machine**, which contradicts the deck's open item ("No `gh` on the
dev machines"). It is authenticated as `eric-cerio` through the keyring, but **an invalid
`GITHUB_TOKEN` in the environment overrides that and breaks every `gh` call**:

```
X Failed to log in to github.com using token (GITHUB_TOKEN)
  - The token in GITHUB_TOKEN is invalid.
✓ Logged in to github.com account eric-cerio (keyring)
```

This is the same invalid token that stops `npm install @eplayment/cli` from GitHub Packages. Fixing
or unsetting it makes `gh pr create --draft` work, and stage 09 can then open the draft PR itself
rather than handing over a command.

## What changes in the plan

1. Hooks move to `com.github.copilot/hooks/hooks.json` (File Structure, Tasks 1, 3 and 4).
2. `hooks/lib.sh` parses `toolArgs` as a nested object; the test payloads use that shape.
3. The shell tool is `bash`; the rails may match on the tool name as well as the `command` field.
4. Task 15 uses the "chains invoke the stage skills" variant. The read-by-path fallback is not
   needed.
5. The ticket file stays at `<git-common-dir>/android-workflow/<KEY>.md`.
6. Task 11's draft-PR step uses `gh pr create --draft`, and says plainly that it needs a valid
   GitHub credential — an invalid `GITHUB_TOKEN` in the environment breaks it.

Cost of this run: about 38 AI credits across four CLI sessions.
