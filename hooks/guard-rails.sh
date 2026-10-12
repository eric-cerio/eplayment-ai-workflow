#!/usr/bin/env bash
# preToolUse: the four rails. Inert outside repositories configured for this workflow.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

payload="$(cat)"
explicit=""; [ "${1:-}" = "--host" ] && explicit="${2:-}"

# Catastrophic path: the library is what defines allow/deny, so it cannot be relied on to report
# its own absence. Emit a decision here, before sourcing, or a broken install silently allows.
# Copilot's form for a Copilot payload (exit 0, verified); every other form, with exit 2, otherwise.
fail_closed() {
  case "$payload" in
    *android-workflow-rails-canary*|*"git push"*|*"git commit"*|*"git add"*|*"git reset"*)
      r="guard-rails hook could not load its library; blocking this command. Reinstall the plugin."
      case "$payload" in
        *'"toolArgs"'*) printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$r"; exit 0 ;;
      esac
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"},"decision":"deny","reason":"%s"}\n' "$r" "$r"
      printf '%s\n' "$r" >&2
      exit 2 ;;
  esac
  printf '{}\n'
  exit 0
}
{ . "$DIR/lib.sh" && . "$DIR/codec.sh"; } 2>/dev/null || fail_closed

HOOK_HOST="$(detect_host "$payload" "$explicit")"
decode "$payload"
# The canary (shared/rails-check.md) proves this hook runs. It is answered before anything else, in
# every repository, so the answer depends on nothing but the hook being wired in.
case "$payload" in
  *android-workflow-rails-canary*) deny "rails live: the android-workflow guard hook is running." ;;
esac
cwd="$(json_field "$payload" cwd)"; [ -n "$cwd" ] || cwd="$PWD"
cmd="$CMD"
# A tool the codec does not list (or a payload in no known shape): the rails cannot be applied, so
# git writes are refused rather than waved through. Its command is still findable for that decision.
[ "$KIND" = other ] && cmd="$(json_field "$payload" command)"

# Fail closed for git commands that write, open for everything else.
writes_git=0
case "$cmd" in *"git push"*|*"git commit"*|*"git add"*|*"git reset"*) writes_git=1 ;; esac
on_error() {
  [ "$writes_git" -eq 1 ] && deny "guard-rails hook failed; blocking this git command. Run tests/run.sh."
  allow
}
trap on_error ERR

root="$(repo_root "$cwd")" || allow
[ -n "$root" ] || allow
has_workflow_config "$root" || allow
cfg="$root/.ai/project/android-workflow.yml"
if [ "$KIND" = other ]; then
  [ "$writes_git" -eq 1 ] && deny "Blocked: the guard hook did not recognize this tool's payload, so it cannot check this git command. Run tests/run.sh."
  allow
fi

# The configured list is a superset request, never a way to unprotect the three base branches:
# a config narrowed by hand (or by a mistaken onboarding) cannot open a hole here.
protected="$(printf 'develop\nmain\nmaster\n%s\n' "$(cfg_list "$cfg" protected_branches)" | grep -v '^$' | sort -u)"
branch="$(current_branch "$root")"
is_protected() { printf '%s\n' "$protected" | grep -qx -- "$1"; }

if [ "$KIND" = shell ] && [ -n "$cmd" ]; then
  case "$cmd" in
    *"git push"*)
      case "$cmd" in
        *" -f "*|*" -f"|*"--force"*|*" +"*)
          deny "Blocked: force-push. Rewriting a pushed branch is not allowed by this workflow." ;;
      esac
      # Last bare word after `git push`, ignoring flags, is the branch (if any).
      target="$(printf '%s' "$cmd" | sed 's/.*git push//' | tr ' ' '\n' \
                | grep -v '^-' | grep -v '^$' | tail -1)"
      if [ -n "$target" ] && [ "$target" != "origin" ] && is_protected "$target"; then
        deny "Blocked: '$target' is protected. Push your working branch instead (feature/<KEY> or bugfix/<name>)."
      fi
      if { [ -z "$target" ] || [ "$target" = "origin" ]; } && [ -n "$branch" ] && is_protected "$branch"; then
        deny "Blocked: HEAD is on protected branch '$branch'. Switch to a working branch first."
      fi ;;
    *"git commit"*)
      if [ -n "$branch" ] && is_protected "$branch"; then
        deny "Blocked: HEAD is on protected branch '$branch'. Commit on feature/<KEY> or bugfix/<name>."
      fi ;;
    *"git add"*)
      staged="$(printf '%s' "$cmd" | sed 's/.*git add//')"
      case "$staged" in
        *" -A"*|*" --all"*|*" ."*|*" -u"*)
          hits="$(git -C "$root" status --porcelain 2>/dev/null | awk '{print $NF}' \
                  | grep -E "$secret_pattern" || true)"
          if [ -n "$hits" ]; then
            deny "Blocked: a secret file has uncommitted changes and would be staged: $(printf '%s' "$hits" | tr '\n' ' '). Stage files explicitly."
          fi ;;
      esac
      if printf '%s' "$staged" | tr ' ' '\n' | grep -v '^-' | grep -qE "$secret_pattern"; then
        deny "Blocked: that path looks like a secret or keystore. This workflow never commits credentials."
      fi ;;
  esac
  case "$cmd" in
    *versionCode*)
      case "$cmd" in
        *"sed -i"*|*"perl -pi"*|*">"*|*"tee "*)
          deny "Blocked: versionCode is owned by CI and release, never by this workflow." ;;
      esac ;;
  esac
fi

# File edits: versionCode inside a Gradle file. The whole payload is searched, not one field, so an
# edit list (MultiEdit) or a patch is covered as well as a single replacement.
if [ "$KIND" = edit ]; then
  case "$payload" in
    *versionCode*)
      if printf '%s\n' "$EDIT_PATHS" | grep -qE '\.gradle(\.kts)?$'; then
        deny "Blocked: versionCode is owned by CI and release, never by this workflow."
      fi ;;
  esac
fi

allow
