#!/usr/bin/env bash
# Host codec: which tool called the hook, what it asked for, and how to answer it.
# Sourced after lib.sh by guard-rails.sh and post-edit.sh. Payload shapes and reply forms:
# docs/superpowers/specs/2026-10-12-multi-host-portability-design.md, sections 4 and 5.2.
#
#   copilot  {"toolName":"bash","toolArgs":{"command":…}}                 deny: JSON on stdout, exit 0
#   claude   {"tool_name":"Bash","tool_input":{…}}  — Claude Code and Codex  deny: stderr, exit 2
#   gemini   {"tool_name":"run_shell_command","tool_input":{…}}             deny: stderr, exit 2
#   unknown  anything else                                                  deny: every form, exit 2

# detect_host <payload> [explicit] — the explicit --host value wins; otherwise the payload's shape.
detect_host() {
  if [ -n "${2:-}" ]; then printf '%s' "$2"; return; fi
  case "$1" in
    *'"toolArgs"'*) printf 'copilot' ;;
    *'"tool_input"'*)
      case "$(json_field "$1" tool_name)" in
        run_shell_command|write_file|replace) printf 'gemini' ;;
        *) printf 'claude' ;;
      esac ;;
    *) printf 'unknown' ;;
  esac
}

# patch_paths <patch text, JSON-escaped> — the files an apply_patch adds, updates or moves to.
patch_paths() {
  printf '%s' "$1" | awk '{ gsub(/\\n/, "\n"); print }' \
    | sed -n -E -e 's/^\*\*\* (Add|Update) File: (.*)$/\2/p' -e 's/^\*\*\* Move to: (.*)$/\1/p'
}

# decode <payload> — sets TOOL, KIND (shell|edit|other), CMD and EDIT_PATHS (one per line).
# Only a shell tool has a CMD: an apply_patch also carries its text in "command", and that text is
# file content, not something about to run.
decode() {
  TOOL="$(json_field "$1" toolName)"; [ -n "$TOOL" ] || TOOL="$(json_field "$1" tool_name)"
  KIND=other; CMD=""; EDIT_PATHS=""
  case "$TOOL" in
    bash|Bash|run_shell_command)
      KIND=shell; CMD="$(json_field "$1" command)" ;;
    apply_patch)
      KIND=edit
      EDIT_PATHS="$(printf '%s\n%s\n%s\n' "$(json_field "$1" path)" "$(json_field "$1" file_path)" \
                    "$(patch_paths "$(json_field "$1" command)$(json_field "$1" input)")" \
                    | grep -v '^$' || true)" ;;
    edit|create|str_replace_editor|write|Edit|Write|MultiEdit|write_file|replace)
      KIND=edit
      EDIT_PATHS="$(json_field "$1" path)"; [ -n "$EDIT_PATHS" ] || EDIT_PATHS="$(json_field "$1" file_path)" ;;
  esac
}

# allow — let the call run.
allow() { printf '{}\n'; exit 0; }

# deny <reason> — block the call in the form HOOK_HOST understands.
deny() {
  r="$(printf '%s' "$1" | sed 's/"/\\"/g')"
  case "${HOOK_HOST:-unknown}" in
    copilot) printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$r"; exit 0 ;;
    claude)  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$r" ;;
    gemini)  printf '{"decision":"deny","reason":"%s"}\n' "$r" ;;
    *)       printf '{"permissionDecision":"deny","permissionDecisionReason":"%s","decision":"deny","reason":"%s"}\n' "$r" "$r" ;;
  esac
  printf '%s\n' "$1" >&2
  exit 2
}

# advise <text> — advisory context for the model after an edit. Never blocks.
advise() {
  t="$(printf '%s' "$1" | sed 's/"/\\"/g' | tr '\n' ' ')"
  case "${HOOK_HOST:-unknown}" in
    copilot) printf '{"additionalContext":"%s"}\n' "$t" ;;
    claude)  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$t" ;;
    gemini)  printf '{"systemMessage":"%s"}\n' "$t" ;;
    *)       printf '{}\n' ;;
  esac
  exit 0
}
