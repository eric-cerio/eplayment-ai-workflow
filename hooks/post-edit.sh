#!/usr/bin/env bash
# postToolUse: run this repository's own checks against the file that was just edited.
# Advisory only — it reports, it never blocks. Blocking is guard-rails.sh's job.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

payload="$(cat)"

# A broken library must not break editing: this hook allows on any failure.
. "$DIR/lib.sh" 2>/dev/null || { printf '{}\n'; exit 0; }

tool="$(json_field "$payload" toolName)"
case "$tool" in edit|create|str_replace_editor|apply_patch|write) ;; *) allow ;; esac

file="$(json_field "$payload" path)"
[ -n "$file" ] || file="$(json_field "$payload" file_path)"
[ -n "$file" ] || allow

cwd="$(json_field "$payload" cwd)"; [ -n "$cwd" ] || cwd="$PWD"
root="$(repo_root "$cwd")" || allow
[ -n "$root" ] || allow
has_workflow_config "$root" || allow

out=""
while IFS= read -r check; do
  [ -n "$check" ] || continue
  [ -x "$root/$check" ] || continue
  result="$("$root/$check" "$file" 2>&1)" || true
  [ -n "$result" ] && out="$out$result
"
done <<EOF
$(cfg_list "$root/.ai/project/android-workflow.yml" "  post_edit_checks")
EOF

if [ -n "$out" ]; then
  printf '{"additionalContext":"%s"}\n' \
    "$(printf '%s' "$out" | sed 's/"/\\"/g' | tr '\n' ' ')"
else
  printf '{}\n'
fi
exit 0
