#!/usr/bin/env bash
# Runs every tests/cases/*.case against hooks/guard-rails.sh (or the hook named in the case).
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0
for case_file in "$root"/tests/cases/*.case; do
  name="$(basename "$case_file" .case)"
  expect="$(sed -n 's/^# expect: //p' "$case_file" | head -1)"
  match="$(sed -n 's/^# match: //p' "$case_file" | head -1)"
  fixture="$(sed -n 's/^# fixture: //p' "$case_file" | head -1)"
  hook="$(sed -n 's/^# hook: //p' "$case_file" | head -1)"; hook="${hook:-guard-rails.sh}"
  if [ ! -x "$root/hooks/$hook" ]; then
    printf 'FAIL %s\n  hook not executable: hooks/%s\n' "$name" "$hook"; fail=$((fail+1)); continue
  fi
  dir=""; [ -n "$fixture" ] && dir="$("$root/tests/fixtures/new-repo.sh" "$fixture")"
  payload="$(grep -v '^# ' "$case_file" | sed "s#\$FIXTURE#${dir}#g")"
  out="$(printf '%s' "$payload" | "$root/hooks/$hook" 2>&1)"; rc=$?
  decision="allow"
  case "$out" in *'"deny"'*) decision="deny" ;; esac
  ok=1
  [ $rc -eq 0 ] || { ok=0; out="hook exited $rc: $out"; }
  [ "$decision" = "$expect" ] || ok=0
  if [ -n "$match" ]; then case "$out" in *"$match"*) ;; *) ok=0 ;; esac; fi
  if [ $ok -eq 1 ]; then pass=$((pass+1)); else
    fail=$((fail+1)); printf 'FAIL %s\n  expected: %s %s\n  got: %s\n' "$name" "$expect" "$match" "$out"
  fi
  [ -n "$dir" ] && rm -rf "$dir"
done
# Fail-closed: a hook that cannot load its library must still block git writes.
lib="$root/hooks/lib.sh"
chmod 000 "$lib"
fc_out="$(printf '{"cwd":"%s","toolName":"bash","toolArgs":{"command":"git push origin feature/x"}}' "$root" | "$root/hooks/guard-rails.sh" 2>/dev/null)"
chmod 644 "$lib"
case "$fc_out" in
  *'"deny"'*) pass=$((pass+1)) ;;
  *) fail=$((fail+1)); printf 'FAIL fail-closed-without-lib\n  expected: deny\n  got: %s\n' "$fc_out" ;;
esac

printf '%d passed, %d failed\n' "$pass" "$fail"
[ $fail -eq 0 ]
