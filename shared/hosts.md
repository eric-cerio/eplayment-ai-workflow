# Hosts

Everything in this workflow that differs between the tools it runs in. Skills never name a tool;
they point here. Copilot and Claude Code rows are verified on a real install
(`docs/checks/`); Codex and Gemini rows are from their documentation, checked 2026-10-12, and
unverified.

## Running a skill

| Tool | How |
|---|---|
| Copilot | `ticket TA-1234`, or ask in words |
| Claude Code | `android-workflow:ticket TA-1234`, or ask in words (form `/<plugin>:<skill>`, from https://code.claude.com/docs/en/plugins/install) |
| Codex | `$ticket TA-1234`, or ask in words (`$` form not confirmed for plugin skills, from https://developers.openai.com/codex/plugins/build/, not confirmed 2026-10-12) |
| Gemini | ask in words: "run the ticket skill for TA-1234" |

## Signing in to Jira (the Atlassian MCP server)

| Tool | How |
|---|---|
| Copilot | `/mcp`, choose `atlassian`, sign in with your own Atlassian account |
| Claude Code | `/mcp`, choose `atlassian`, authenticate |
| Codex | `codex mcp login atlassian` (from https://developers.openai.com/codex/plugins/build/, not confirmed 2026-10-12) |
| Gemini | `/mcp auth atlassian` (from https://geminicli.com/docs/hooks/, not confirmed 2026-10-12) |

## Updating the plugin

| Tool | How |
|---|---|
| Copilot | `copilot plugin update --all` |
| Claude Code | `claude plugin marketplace update eplayment`, then `claude plugin update android-workflow@eplayment` (https://code.claude.com/docs/en/plugins/install) |
| Codex | `codex plugin marketplace upgrade eplayment` (https://developers.openai.com/codex/plugins/build/) |
| Gemini | `gemini extensions update android-workflow` (https://geminicli.com/docs/extensions/reference/) |

## When the rails check fails

The guard hook is not running. Fix it for your tool, start a new session, and rerun.

| Tool | Fix |
|---|---|
| Copilot | `copilot plugin list` must show `android-workflow`; reinstall it if not |
| Claude Code | `/plugin` must show `android-workflow` enabled; `/hooks` must list its `PreToolUse` hook (`/hooks` from the brief, not confirmed against https://code.claude.com/docs/en/plugins/install 2026-10-12) |
| Codex | hooks are on by default (https://learn.chatgpt.com/docs/hooks). If they were turned off, remove `hooks = false` under `[features]` in `config.toml`. If your organization's `requirements.toml` sets `[features].hooks = false`, this workflow cannot run in Codex |
| Gemini | `gemini extensions list` must show `android-workflow` enabled (from https://geminicli.com/docs/extensions/reference/, not confirmed 2026-10-12; the page documents `/extensions list` in interactive mode); hooks run by default (geminicli.com/docs/hooks, checked 2026-10-12) |
