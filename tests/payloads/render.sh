#!/usr/bin/env bash
# Renders a host-neutral case into the payload one host sends its tool hook.
# Usage: render.sh <copilot|claude|codex|gemini> <case file> <fixture dir>
# Shapes: spec 2026-10-12-multi-host-portability-design.md, section 4; Copilot's from
# docs/checks/2026-09-20-platform-checks.md.
set -eu
host="$1"; case_file="$2"; fx="$3"
hdr() { sed -n "s/^# $1: //p" "$case_file" | head -1 | sed "s#\$FIXTURE#${fx}#g"; }
esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
kind="$(hdr kind)"
cmd="$(esc "$(hdr cmd)")"; path="$(esc "$(hdr path)")"
old="$(esc "$(hdr old)")"; new="$(esc "$(hdr new)")"; cwd="$(esc "$fx")"
patch="*** Begin Patch\\n*** Update File: ${path}\\n@@\\n-${old}\\n+${new}\\n*** End Patch\\n"
case "$host:$kind" in
  copilot:shell) printf '{"sessionId":"s","timestamp":0,"cwd":"%s","toolName":"bash","toolArgs":{"command":"%s"}}\n' "$cwd" "$cmd" ;;
  copilot:edit)  printf '{"sessionId":"s","timestamp":0,"cwd":"%s","toolName":"str_replace_editor","toolArgs":{"path":"%s","old_str":"%s","new_str":"%s"}}\n' "$cwd" "$path" "$old" "$new" ;;
  claude:shell)  printf '{"session_id":"s","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}\n' "$cwd" "$cmd" ;;
  claude:edit)   printf '{"session_id":"s","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"%s","new_string":"%s"}}\n' "$cwd" "$path" "$old" "$new" ;;
  codex:shell)   printf '{"session_id":"s","turn_id":"t","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}\n' "$cwd" "$cmd" ;;
  codex:edit)    printf '{"session_id":"s","turn_id":"t","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"apply_patch","tool_input":{"command":"%s"}}\n' "$cwd" "$patch" ;;
  gemini:shell)  printf '{"session_id":"s","hook_event_name":"BeforeTool","cwd":"%s","tool_name":"run_shell_command","tool_input":{"command":"%s"}}\n' "$cwd" "$cmd" ;;
  gemini:edit)   printf '{"session_id":"s","hook_event_name":"BeforeTool","cwd":"%s","tool_name":"replace","tool_input":{"file_path":"%s","old_string":"%s","new_string":"%s"}}\n' "$cwd" "$path" "$old" "$new" ;;
  *) printf 'render.sh: no payload for %s\n' "$host:$kind" >&2; exit 1 ;;
esac
