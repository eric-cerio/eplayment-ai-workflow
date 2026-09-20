#!/usr/bin/env bash
# Shared helpers for the Copilot hooks. No jq, no python: neither is guaranteed on a dev Mac.
#
# Payload shape (verified 2026-09-21, Copilot CLI 1.0.85):
#   {"sessionId":"…","timestamp":123,"cwd":"/path","toolName":"bash",
#    "toolArgs":{"command":"git push …","description":"…"}}
# toolArgs is a nested OBJECT, not an escaped JSON string.

allow() { printf '{}\n'; exit 0; }
deny()  { printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' \
            "$(printf '%s' "$1" | sed 's/"/\\"/g')"; exit 0; }

# json_field <json> <key> — a string field anywhere in the payload, JSON-unescaped.
# BSD sed has no GNU alternation in BRE, so these use -E (ERE), which macOS and Linux both have.
# Keys like command/path only occur inside toolArgs, so there is no need to slice it out first.
json_field() {
  printf '%s' "$1" | tr -d '\n' \
    | sed -E -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"(([^\"\\\\]|\\\\.)*)\".*/\\1/p" \
    | head -1 | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}

repo_root() { git -C "$1" rev-parse --show-toplevel 2>/dev/null; }
has_workflow_config() { [ -f "$1/.ai/project/android-workflow.yml" ]; }
current_branch() { git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null; }

# cfg_list <config file> <key> — inline (key: [a, b]) or block (key:\n  - a) list.
# Never returns non-zero: an empty list is a normal answer, and the callers run under an ERR trap.
cfg_list() {
  f="$1"; k="$2"
  { sed -n "s/^$k:[[:space:]]*\[\(.*\)\].*/\1/p" "$f" | tr ',' '\n' | sed 's/[][ "]//g' | grep -v '^$'
    sed -n "/^$k:[[:space:]]*$/,/^[^[:space:]-]/{s/^[[:space:]]*-[[:space:]]*//p;}" "$f" \
      | sed 's/"//g' | grep -v '^$'
  } || true
}

# secret_pattern — one grep -E pattern for paths this workflow never commits.
secret_pattern='\.(jks|keystore|p12|pem)$|credentials.*\.json$|(^|/)local\.properties$|(^|/)keystore\.properties$'
