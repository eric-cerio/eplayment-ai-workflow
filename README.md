# android-workflow

The Eplayment Android development workflow, as a GitHub Copilot plugin. Ten stages from Jira ticket
to distribution note, three human gates, and four rails enforced by a hook rather than by good
intentions.

**Every stage is a skill you can run on its own.** Plan a fix without writing code, run the tests
for one feature, check security on your current diff. `/ticket` and `/bugfix` chain those same
skills into the full run.

## Install

```bash
copilot plugin install eplayment/ai-workflow
copilot plugin update --all        # later, to pick up changes
```

Then, once per repository:

```
/android-onboard
```

It detects the repo's build, versioning, release-notes and distribution conventions and writes
`.ai/project/android-workflow.yml`. Everything repo-specific lives in that file — see
[`shared/config.md`](shared/config.md).

## Supported surfaces

Verified in **Copilot CLI 1.0.85**. Android Studio (Copilot plugin 1.11.0) loads skills that live
in the repository and responds to them when asked in plain words, but does not offer them as slash
commands; whether an installed *plugin* reaches the IDE is unverified until this repo is published.
See [`docs/checks/2026-09-20-platform-checks.md`](docs/checks/2026-09-20-platform-checks.md).

## The skills

| Skill | Stage | Stops for you |
|---|---|---|
| `/ticket <KEY>` | chain: plan → branch → develop → ship | at each gate below |
| `/bugfix <KEY>` | the same, in fix mode | at each gate below |
| `/android-ship` | chain: stages 05→10 | at gates 2 and 3 |
| `/android-plan <KEY> [feature\|fix]` | 01+02 | **gate 1** — the plan |
| `/android-branch` | 03 | — |
| `/android-develop` | 04 | — |
| `/android-lint` | 05 | — |
| `/android-release-notes` | 06 | — |
| `/android-test [scope]` | 07 | — |
| `/android-security-gate` | 08 | **gate 2** — high severity blocks the push |
| `/android-commit-push` | 09 | **gate 3** — message, files and target, then your yes |
| `/android-dist-note` | 10 | asks prod or QA |
| `/android-onboard` | setup | asks about what it cannot detect |

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
./tests/lint-skills.sh          # frontmatter, references, no repo-specific strings
./tests/run.sh                  # the hook, against sample tool calls
```

Run both before tagging a release: everyone auto-updates to latest, so a broken rail reaches the
whole team at their next `copilot plugin update`.

The design and the task-by-task plan are in [`docs/superpowers/`](docs/superpowers/).
