# Host checklist — Codex and Gemini

Codex and Gemini support is built from their documentation and is **unverified**. Run this on an
install your organization has approved for company work (`.ai/company/ai-usage-policy.md`), in a
scratch repository from `tests/fixtures/new-repo.sh on-feature`, never in a real app repository.
Record the result in a new `docs/checks/<date>-<tool>-checks.md`, and change the tool's row in the
README's "Supported surfaces" from unverified to verified only if every check passes.

## Install

| Tool | Install |
|---|---|
| Codex | `codex plugin marketplace add eric-cerio/eplayment-ai-workflow`, then install `android-workflow` from the marketplace; hooks are on by default; if your config or your organization's requirements.toml sets `hooks = false`, the rails cannot run (see `shared/hosts.md`) |
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
