# Check 7 — can the plugin declare an MCP server? — 2026-09-22

Run against Copilot CLI **1.0.87** on macOS 25.4. Needed because `android-plan` is to read Jira
through the Atlassian MCP server, and the question was whether the plugin can ship that server's
declaration or every developer has to add it by hand.

**Answer: yes, with one path.** A plugin that declares the Agent Plugins v1 `$schema` (as
`plugin.json` here does) reads its MCP servers only from **`mcp.json` at the plugin root** — no
leading dot, not under `com.github.copilot/`.

## Method

Throwaway plugins, each with one skill and one HTTP MCP server pointing at `https://example.invalid/mcp`
under a unique name, loaded with `--plugin-dir` into a one-line `copilot -p` session at
`--log-level debug`. A server the CLI picked up shows in the log as a connection attempt to
`example.invalid`; one it ignored does not appear at all.

`copilot mcp list` and `copilot mcp get` do **not** answer this: they list servers from installed
plugins only, and ignore `--plugin-dir`. Even the control variant was missing from them.

| Variant | `$schema` v1 | Where the server was declared | Loaded |
|---|---|---|---|
| A | yes | `.mcp.json` at the root | no |
| B | yes | `com.github.copilot/mcp.json` | no |
| C | yes | `com.github.copilot/.mcp.json` | no |
| D | yes | `plugin.json` → `extensions."com.github.copilot".mcpServers` | no |
| E | no | `.mcp.json` at the root (the layout the installed `figma` plugin uses) | **yes** |
| F | yes | **`mcp.json` at the root** | **yes** |
| G | yes | `com.github.copilot/mcp/mcp.json` (mirroring the hooks path) | no |

The CLI said so itself, the same way it did for hooks in check 2:

```
[ERROR] [rust:copilot_runtime::config::loader] Plugin "a" declares the Agent Plugins v1 $schema,
so its MCP servers are read only from "mcp.json". ".mcp.json" at the plugin root is no longer
read; move it there.
```

Variant F then started:

```
[DEBUG] [rust:copilot_runtime::session::mcp::session_host] mcp discover_and_start_root
  {"signature":"{\"servers\":[[\"c7-root-mcpjson\",\"{...\\\"type\\\":\\\"http\\\",\\\"url\\\":\\\"https://example.invalid/mcp\\\"}\"...
[DEBUG] [rust:rt_mcp::native_host] Recorded failure for server c7-root-mcpjson: failed to initialize
  MCP client: ... error sending request for url (https://example.invalid/mcp)
```

The failure is the expected one — the host does not exist — and proves the declaration was read.

## What this settles, and what it does not

- The plugin can ship `mcp.json` with the Atlassian server's URL and no credentials. Sign-in stays
  per developer (OAuth), so nothing secret enters the repository.
- **Unlike the hooks, a plugin MCP server is not inert outside Android repos.** It is declared for
  every session in every directory once the plugin is installed. An unauthenticated remote server
  costs a failed connection, not a failure of the session, but it is visible in `/mcp`.
- **Name clashes.** A developer who already added an Atlassian server by hand in
  `~/.copilot/mcp-config.json` would see two. The skill must not depend on the server's name.
- **Not verified here:** the OAuth sign-in against the real Atlassian endpoint (a developer's own
  login, done during manual acceptance), and **Android Studio**, whose bundled agent runtime is
  1.0.56 — older than the CLI that introduced this rule. Treat plugin MCP servers in the IDE as
  unproven until tested there, the same status check 1 still has.

Cost of this check: about 17 AI credits across two CLI sessions.
