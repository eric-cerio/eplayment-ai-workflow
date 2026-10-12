#!/usr/bin/env bash
# Runs every tests/cases/*.case against its hook once per host, with the payload that host sends
# (tests/payloads/render.sh), and checks the reply is in that host's form. A case with a body is a
# raw payload, run once, its reply form named by '# reply:'.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOSTS="copilot claude codex gemini"
pass=0; fail=0
errf="$(mktemp)"
hdr() { sed -n "s/^# $1: //p" "$2" | head -1; }

# verdict <label> <host> <hook> <expect> <match> <rc> <stdout> <stderr>
verdict() {
  label="$1"; host="$2"; hook="$3"; expect="$4"; match="$5"; rc="$6"; out="$7"; err="$8"; why=""
  if [ "$expect" = deny ]; then
    case "$host" in
      copilot) [ "$rc" -eq 0 ] || why="$why exit=$rc(want 0);"
               case "$out" in *'"permissionDecision":"deny"'*) ;; *) why="$why no copilot deny on stdout;" ;; esac ;;
      claude|codex)
               [ "$rc" -eq 2 ] || why="$why exit=$rc(want 2);"
               case "$out" in *'"hookSpecificOutput"'*'"permissionDecision":"deny"'*) ;; *) why="$why no hookSpecificOutput deny;" ;; esac ;;
      gemini)  [ "$rc" -eq 2 ] || why="$why exit=$rc(want 2);"
               case "$out" in *'"decision":"deny"'*) ;; *) why="$why no gemini decision deny;" ;; esac ;;
      unknown) [ "$rc" -eq 2 ] || why="$why exit=$rc(want 2);"
               case "$out" in *'"permissionDecision":"deny"'*'"decision":"deny"'*) ;; *) why="$why not denied in every form;" ;; esac ;;
      *)       why="$why unknown reply form '$host';" ;;
    esac
    if [ -n "$match" ]; then
      case "$host" in
        copilot) case "$out" in *"$match"*) ;; *) why="$why '$match' not on stdout;" ;; esac ;;
        *)       case "$err" in *"$match"*) ;; *) why="$why '$match' not on stderr;" ;; esac ;;
      esac
    fi
  else
    [ "$rc" -eq 0 ] || why="$why exit=$rc(want 0);"
    case "$out" in *'"deny"'*) why="$why denied;" ;; esac
    if [ -n "$match" ]; then
      case "$out" in *"$match"*) ;; *) why="$why '$match' not on stdout;" ;; esac
      if [ "$hook" = post-edit.sh ]; then
        case "$host" in
          copilot) key='"additionalContext"' ;;
          claude|codex) key='"hookSpecificOutput"' ;;
          gemini) key='"systemMessage"' ;;
          *) key=''; why="$why unknown reply form '$host';" ;;
        esac
        case "$out" in *"$key"*) ;; *) why="$why advice not in $host form;" ;; esac
      fi
    fi
  fi
  if [ -z "$why" ]; then pass=$((pass+1)); else
    fail=$((fail+1)); printf 'FAIL %s\n  %s\n  stdout: %s\n  stderr: %s\n' "$label" "$why" "$out" "$err"
  fi
}

# run_one <label> <host> <hook> <expect> <match> <payload> [hook args…]
run_one() {
  label="$1"; host="$2"; hook="$3"; expect="$4"; match="$5"; payload="$6"; shift 6
  out="$(printf '%s' "$payload" | "$root/hooks/$hook" "$@" 2>"$errf")"; rc=$?
  verdict "$label" "$host" "$hook" "$expect" "$match" "$rc" "$out" "$(cat "$errf")"
}

for case_file in "$root"/tests/cases/*.case; do
  name="$(basename "$case_file" .case)"
  expect="$(hdr expect "$case_file")"; match="$(hdr match "$case_file")"
  fixture="$(hdr fixture "$case_file")"
  hook="$(hdr hook "$case_file")"; hook="${hook:-guard-rails.sh}"
  only="$(hdr hosts "$case_file")"
  if [ ! -x "$root/hooks/$hook" ]; then
    printf 'FAIL %s\n  hook not executable: hooks/%s\n' "$name" "$hook"; fail=$((fail+1)); continue
  fi
  dir=""; [ -n "$fixture" ] && dir="$("$root/tests/fixtures/new-repo.sh" "$fixture")"
  raw="$(grep -v '^#' "$case_file" | grep -v '^[[:space:]]*$' || true)"
  if [ -n "$raw" ]; then
    reply="$(hdr reply "$case_file")"
    if [ -z "$reply" ]; then fail=$((fail+1)); printf 'FAIL %s\n  raw case has no # reply:\n' "$name"; [ -n "$dir" ] && rm -rf "$dir"; continue; fi
    run_one "$name" "$reply" "$hook" "$expect" "$match" "$(printf '%s' "$raw" | sed "s#\$FIXTURE#${dir}#g")"
  else
    for host in ${only:-$HOSTS}; do
      payload="$("$root/tests/payloads/render.sh" "$host" "$case_file" "$dir")" || payload=""
      if [ -z "$payload" ]; then fail=$((fail+1)); printf 'FAIL %s[%s]\n  render failed\n' "$name" "$host"; continue; fi
      if [ "$host" = gemini ]; then
        run_one "$name[$host]" "$host" "$hook" "$expect" "$match" "$payload" --host gemini
      else
        run_one "$name[$host]" "$host" "$hook" "$expect" "$match" "$payload"
      fi
    done
  fi
  [ -n "$dir" ] && rm -rf "$dir"
done

# Fail-closed: a hook that cannot load lib.sh or codec.sh must still block git writes and the
# canary, on every host, in that host's form.
fc_case="$(mktemp)"
for broken in lib.sh codec.sh; do
  for cmd in 'git push origin feature/x' ': android-workflow-rails-canary'; do
    printf '# kind: shell\n# cmd: %s\n' "$cmd" > "$fc_case"
    chmod 000 "$root/hooks/$broken"
    for host in $HOSTS; do
      payload="$("$root/tests/payloads/render.sh" "$host" "$fc_case" "$root")"
      if [ "$host" = gemini ]; then
        run_one "fail-closed-$broken[$host] $cmd" "$host" guard-rails.sh deny "could not load" "$payload" --host gemini
      else
        run_one "fail-closed-$broken[$host] $cmd" "$host" guard-rails.sh deny "could not load" "$payload"
      fi
    done
    chmod 644 "$root/hooks/$broken"
  done
done
rm -f "$fc_case"

# An explicit --host is normalised: codex speaks the Claude form, anything unlisted is unknown.
dh_out="$( cd "$root" && . hooks/lib.sh && . hooks/codec.sh && detect_host '{}' codex && echo && detect_host '{}' bogus )"
if [ "$dh_out" = "$(printf 'claude\nunknown')" ]; then pass=$((pass+1))
else fail=$((fail+1)); printf 'FAIL detect-host-explicit-normalised\n  got: %s\n' "$dh_out"; fi

# The diff fingerprint, taken from its contract in shared/ticket-file.md, must change when a new
# (untracked) file's contents change — else a pass survives code added after the gate — and must
# not change when nothing does.
fp_cmd="$(awk '/^## The diff fingerprint/{s=1} s&&/^```bash/{c=1;next} c&&/^```/{exit} c' \
  "$root/shared/ticket-file.md" | sed 's/<base_branch>/develop/g')"
fp_dir="$(mktemp -d)"
if ( cd "$fp_dir" && git init -q -b develop . && git config user.email t@example.com \
     && git config user.name Test && printf 'a\n' > a.txt && git add a.txt && git commit -qm init \
     && git checkout -qb feature/TA-1 && printf 'val x = 1\n' > New.kt \
     && one="$(bash -c "$fp_cmd")" && again="$(bash -c "$fp_cmd")" \
     && printf 'val y = 2\n' >> New.kt && two="$(bash -c "$fp_cmd")" \
     && [ -n "$one" ] && [ "$one" = "$again" ] && [ "$one" != "$two" ] ); then
  pass=$((pass+1))
else
  fail=$((fail+1)); printf 'FAIL fingerprint-covers-untracked-content\n  command: %s\n' "$fp_cmd"
fi
rm -rf "$fp_dir"

rm -f "$errf"
printf '%d passed, %d failed\n' "$pass" "$fail"
[ $fail -eq 0 ]
