#!/usr/bin/env bash
# postToolUse: run this repository's own checks against the file that was just edited.
# Advisory only — it reports, it never blocks. Blocking is guard-rails.sh's job.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

payload="$(cat)"
explicit=""; [ "${1:-}" = "--host" ] && explicit="${2:-}"

# A broken library must not break editing: this hook allows on any failure.
{ . "$DIR/lib.sh" && . "$DIR/codec.sh"; } 2>/dev/null || { printf '{}\n'; exit 0; }

HOOK_HOST="$(detect_host "$payload" "$explicit")"
decode "$payload"
[ "$KIND" = edit ] || allow
[ -n "$EDIT_PATHS" ] || allow

cwd="$(json_field "$payload" cwd)"; [ -n "$cwd" ] || cwd="$PWD"
root="$(repo_root "$cwd")" || allow
[ -n "$root" ] || allow
has_workflow_config "$root" || allow

checks="$(cfg_list "$root/.ai/project/android-workflow.yml" "  post_edit_checks")"
out=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  while IFS= read -r check; do
    [ -n "$check" ] || continue
    [ -x "$root/$check" ] || continue
    result="$("$root/$check" "$file" 2>&1)" || true
    [ -n "$result" ] && out="$out$result
"
  done <<EOF
$checks
EOF
done <<EOF
$EDIT_PATHS
EOF

[ -n "$out" ] && advise "$out"
allow
