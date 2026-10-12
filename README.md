# android-workflow

The Eplayment Android development workflow, as a plugin for GitHub Copilot, Claude Code, Codex and Gemini. Ten stages from Jira ticket
to distribution note, three human gates, and four rails enforced by a hook rather than by good
intentions.

**Every stage is a skill you can run on its own.** Plan a fix without writing code, run the tests
for one feature, check security on your current diff. `ticket` and `bugfix` chain those same
skills into the full run.

## Install

Installing needs GitHub access to this repository.

### Copilot

```bash
copilot plugin install eric-cerio/eplayment-ai-workflow
copilot plugin update --all        # later, to pick up changes
```

If `gh auth status` reports a working keyring login but installs still fail, check for an invalid
`GITHUB_TOKEN` in your environment — it overrides the keyring, and it breaks `gh` and `npm` the
same way.

### Claude Code

```bash
claude plugin marketplace add eric-cerio/eplayment-ai-workflow
claude plugin install android-workflow@eplayment
```

In headless runs (`claude -p`), grant the plugin folder with `--add-dir <plugin dir>` so the skills
can read their `shared/*.md` files; interactive sessions ask for the read. Evidence:
[`docs/checks/2026-10-12-claude-code-checks.md`](docs/checks/2026-10-12-claude-code-checks.md).

### Codex — unverified

```bash
codex plugin marketplace add eric-cerio/eplayment-ai-workflow
```

Then install `android-workflow` from the `eplayment` marketplace. Codex hooks are on by default; if
your config or your organization's `requirements.toml` sets `hooks = false`, the rails cannot run
and the workflow stops at its rails check (see [`shared/hosts.md`](shared/hosts.md)).

### Gemini — unverified

```bash
gemini extensions install https://github.com/eric-cerio/eplayment-ai-workflow
```

**Codex and Gemini need approval before company use.** Under the AI usage policy, a tool not
approved for company work cannot be used on company code or Jira data. This plugin supporting a
tool does not approve it; ask before installing it for real work.

### First use

Once per repository, run the `android-onboard` skill (how to run a skill in your tool:
[`shared/hosts.md`](shared/hosts.md)).

It detects the repo's build, versioning, release-notes and distribution conventions and writes
`.ai/project/android-workflow.yml`. Everything repo-specific lives in that file — see
[`shared/config.md`](shared/config.md).

### Jira

`android-plan` reads the ticket, and its related `[BE]` and `[UI]` tickets, from Jira through the
Atlassian MCP server this plugin declares in `mcp.json`, `.mcp.json` and `gemini-extension.json` (each tool reads its own). Sign in once with your own Atlassian account — `shared/hosts.md` has the command for each tool. The plugin carries no token and
never writes to Jira.

The server is declared in every session of every tool once the plugin is installed, not only in Android repositories. Signed out, it costs nothing but an unconnected server line.

## Supported surfaces

| Tool | Version | Status |
|---|---|---|
| Copilot CLI | 1.0.89 | verified — `docs/checks/2026-09-20-platform-checks.md`, re-run in `docs/checks/2026-10-12-claude-code-checks.md` |
| Claude Code | 2.1.296 | verified — `docs/checks/2026-10-12-claude-code-checks.md` |
| Codex CLI | — | built from documentation, **unverified** — `docs/checks/host-checklist.md` |
| Gemini CLI | — | built from documentation, **unverified** — `docs/checks/host-checklist.md` |
| Android Studio (Copilot plugin) | 1.11.0 | partly verified (below) |

What was checked: Copilot 1.0.85 (2026-09-20 checks) verified hooks, the gates and resuming from the
ticket file; the 1.0.89 re-run covered the canary and a protected-branch push deny. Claude Code 2.1.296
covered the canary, a push deny, a versionCode edit deny, a git status allow, skill listing and
`android-ship`'s rails check. Nothing beyond that is claimed.

**Android Studio** — partly verified. It loads skills that live in a
repository and runs them when asked in plain words, but does not offer them as slash commands.
Whether it picks up an *installed plugin* is still unproven: it could not be tested before this
repo existed, because `copilot plugin install` rejects local `file://` sources. Install it and ask
Copilot Chat, in Agent mode, to "run the android-dist-note skill" — that settles it.

Details and evidence: [`docs/checks/2026-09-20-platform-checks.md`](docs/checks/2026-09-20-platform-checks.md).

## The skills

How to run a skill differs by tool — see `shared/hosts.md`.

| Skill | Stage | Stops for you |
|---|---|---|
| `ticket <KEY>` | chain: plan → branch → develop → ship | at each gate below |
| `bugfix <KEY>` | the same, in fix mode | at each gate below |
| `android-ship` | chain: stages 05→10 | at gates 2 and 3 |
| `android-plan <KEY> [feature\|fix]` | 01+02 | **gate 1** — the plan; stops first if a `[BE]` or `[UI]` ticket has not passed development |
| `android-branch` | 03 | — |
| `android-develop` | 04 | — |
| `android-lint` | 05 | — |
| `android-release-notes` | 06 | — |
| `android-test [scope]` | 07 | — |
| `android-review` | 07b | — advisory: findings are reported and repeated at gate 3 |
| `android-security-gate` | 08 | **gate 2** — high severity blocks the push |
| `android-commit-push` | 09 | **gate 3** — message, files and target, then your yes |
| `android-dist-note` | 10 | asks prod or QA |
| `android-onboard` | setup | asks about what it cannot detect |

## Picking up where you left off

Each run records what it learns — the ticket details, the approved plan, the branch, the security
result — in `<git-common-dir>/android-workflow/<KEY>.md`. It lives inside `.git`, so it is never
committed and never appears in a diff.

That file is why running the `ticket` skill for TA-1234 tomorrow resumes at the first unfinished stage instead of
asking for the ticket details again, and why `android-commit-push` on its own knows whether the
security gate has passed **for the changes you have now** — it compares a fingerprint of your diff,
so a pass from before your last edit does not count. See [`shared/ticket-file.md`](shared/ticket-file.md).

## The rails

A hook denies these, on every supported tool, before they run, whatever the model decided:

- commit or push to `develop`, `main` or `master`
- force-push
- any change to `versionCode`
- staging a keystore or credentials file

The hook is inert in any repository without `.ai/project/android-workflow.yml`, so it never
interferes with unrelated projects.

**The rails check.** A hook that a tool silently fails to load would leave the rails off with
nothing saying so. So `ticket`, `bugfix`, `android-ship` and `android-commit-push` first run a
harmless command the hook always blocks; if it is not blocked, they stop before any work and before
anything is staged. It proves the shell hook runs. The `versionCode` rail on file edits depends on
the edit-tool names in `hooks/hooks.json`, which lint checks against each tool's documentation.

## Developing

```bash
copilot --plugin-dir "$PWD"     # run the plugin without installing it
claude --plugin-dir "$PWD"      # the same, on Claude Code
./tests/lint-skills.sh          # frontmatter, references, skill names, mcp.json, manifests, hooks.json matchers, host-neutral skills, no repo-specific strings, no ../ paths
./tests/run.sh                  # every hook case on Copilot, Claude Code, Codex and Gemini payloads, fail-closed, fingerprint
```

Run both before tagging a release: everyone auto-updates to latest, so a broken rail reaches the
whole team at their next `copilot plugin update`.

Two things the tests exist to catch, because both have already happened here:

- A hook that **fails open**. `guard-rails.sh` emits a deny before it sources anything, so a broken
  install blocks git writes instead of silently allowing them.
- A rail that is **present in the file and absent in reality**. The payload helpers once used
  GNU-only `sed` syntax and parsed nothing on macOS, so every rail passed everything.

Hooks are wired twice: `com.github.copilot/hooks/hooks.json` for Copilot (a plugin declaring the
Agent Plugins v1 `$schema` is not read from anywhere else), and `hooks/hooks.json` for Claude Code,
Codex and Gemini, which all read that one path — so it carries both the `PreToolUse` and the
`BeforeTool` keys. Every host's payload goes through `hooks/codec.sh`. `claude plugin validate`
prints warnings that `BeforeTool`/`AfterTool` are unknown hook events ignored at runtime; that is
expected, they are Gemini's keys.

The design and the task-by-task plan are in [`docs/superpowers/`](docs/superpowers/).
