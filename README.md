# android-workflow

The Eplayment Android development workflow, as a GitHub Copilot plugin. Ten stages from Jira ticket
to distribution note, three human gates, and four rails enforced by a hook rather than by good
intentions.

**Every stage is a skill you can run on its own.** Plan a fix without writing code, run the tests
for one feature, check security on your current diff. `/ticket` and `/bugfix` chain those same
skills into the full run.

## Install

```bash
copilot plugin install eric-cerio/eplayment-ai-workflow
copilot plugin update --all        # later, to pick up changes
```

Installing needs GitHub access to this repository. If `gh auth status` reports a working keyring
login but installs still fail, check for an invalid `GITHUB_TOKEN` in your environment — it
overrides the keyring, and it breaks `gh` and `npm` the same way.

Then, once per repository:

```
/android-onboard
```

It detects the repo's build, versioning, release-notes and distribution conventions and writes
`.ai/project/android-workflow.yml`. Everything repo-specific lives in that file — see
[`shared/config.md`](shared/config.md).

### Jira

`/android-plan` reads the ticket, and its related `[BE]` and `[UI]` tickets, from Jira through the
Atlassian MCP server this plugin declares in `mcp.json`. Sign in once with your own Atlassian
account when Copilot asks; `/mcp` shows whether it is connected. The plugin carries no token and
never writes to Jira.

The server is declared in every Copilot session once the plugin is installed, not only in Android
repositories. Signed out, it costs nothing but an unconnected line in `/mcp`.

## Supported surfaces

**Copilot CLI 1.0.85** — verified: hooks fire and deny, skills invoke other skills, the three gates
hold, and a run resumes from its ticket file.

**Android Studio** (Copilot plugin 1.11.0) — partly verified. It loads skills that live in a
repository and runs them when asked in plain words, but does not offer them as slash commands.
Whether it picks up an *installed plugin* is still unproven: it could not be tested before this
repo existed, because `copilot plugin install` rejects local `file://` sources. Install it and ask
Copilot Chat, in Agent mode, to "run the android-dist-note skill" — that settles it.

Details and evidence: [`docs/checks/2026-09-20-platform-checks.md`](docs/checks/2026-09-20-platform-checks.md).

## The skills

| Skill | Stage | Stops for you |
|---|---|---|
| `/ticket <KEY>` | chain: plan → branch → develop → ship | at each gate below |
| `/bugfix <KEY>` | the same, in fix mode | at each gate below |
| `/android-ship` | chain: stages 05→10 | at gates 2 and 3 |
| `/android-plan <KEY> [feature\|fix]` | 01+02 | **gate 1** — the plan; stops first if a `[BE]` or `[UI]` ticket has not passed development |
| `/android-branch` | 03 | — |
| `/android-develop` | 04 | — |
| `/android-lint` | 05 | — |
| `/android-release-notes` | 06 | — |
| `/android-test [scope]` | 07 | — |
| `/android-review` | 07b | — advisory: findings are reported and repeated at gate 3 |
| `/android-security-gate` | 08 | **gate 2** — high severity blocks the push |
| `/android-commit-push` | 09 | **gate 3** — message, files and target, then your yes |
| `/android-dist-note` | 10 | asks prod or QA |
| `/android-onboard` | setup | asks about what it cannot detect |

## Picking up where you left off

Each run records what it learns — the ticket details, the approved plan, the branch, the security
result — in `<git-common-dir>/android-workflow/<KEY>.md`. It lives inside `.git`, so it is never
committed and never appears in a diff.

That file is why `/ticket TA-1234` run tomorrow resumes at the first unfinished stage instead of
asking for the ticket details again, and why `/android-commit-push` on its own knows whether the
security gate has passed **for the changes you have now** — it compares a fingerprint of your diff,
so a pass from before your last edit does not count. See [`shared/ticket-file.md`](shared/ticket-file.md).

## The rails

A `preToolUse` hook denies these before they run, whatever the model decided:

- commit or push to `develop`, `main` or `master`
- force-push
- any change to `versionCode`
- staging a keystore or credentials file

The hook is inert in any repository without `.ai/project/android-workflow.yml`, so it never
interferes with unrelated projects.

## Developing

```bash
copilot --plugin-dir "$PWD"     # run the plugin without installing it
./tests/lint-skills.sh          # frontmatter, references, skill names, mcp.json, no repo-specific strings, no ../ paths
./tests/run.sh                  # 21 hook cases plus the diff-fingerprint check, on scratch repositories
```

Run both before tagging a release: everyone auto-updates to latest, so a broken rail reaches the
whole team at their next `copilot plugin update`.

Two things the tests exist to catch, because both have already happened here:

- A hook that **fails open**. `guard-rails.sh` emits a deny before it sources anything, so a broken
  install blocks git writes instead of silently allowing them.
- A rail that is **present in the file and absent in reality**. The payload helpers once used
  GNU-only `sed` syntax and parsed nothing on macOS, so every rail passed everything.

Hooks live at `com.github.copilot/hooks/hooks.json` — a plugin declaring the Agent Plugins v1
`$schema` is not read from anywhere else.

The design and the task-by-task plan are in [`docs/superpowers/`](docs/superpowers/).
