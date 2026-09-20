#!/usr/bin/env bash
# Lints every skill: frontmatter, referenced files exist, no repo-specific strings.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
note() { printf '%s\n' "$1"; fail=1; }

for skill in "$root"/skills/*/SKILL.md; do
  [ -e "$skill" ] || { note "no skills found"; break; }
  dir="$(dirname "$skill")"
  rel="${skill#"$root"/}"

  head -1 "$skill" | grep -qx -- '---' || note "$rel: missing frontmatter opening ---"
  grep -qE '^name: [a-z0-9-]+$' "$skill" || note "$rel: missing or malformed 'name:'"
  grep -qE '^description: .{40,}$' "$skill" || note "$rel: 'description:' missing or shorter than 40 chars"
  [ "$(basename "$dir")" = "$(sed -n 's/^name: //p' "$skill" | head -1)" ] || note "$rel: folder name and 'name:' differ"

  # Referenced sibling/shared files must exist.
  while read -r ref; do
    [ -n "$ref" ] || continue
    [ -e "$dir/$ref" ] || note "$rel: references missing file $ref"
  done < <(grep -oE '(\.\./)+[A-Za-z0-9_./-]+\.md' "$skill" | sort -u)

  # Repo-specific strings are configuration, not skill content.
  if grep -qE '/Users/|eplayment-pixel-android|eplayment-android|keri-android|mannypay-android' "$skill"; then
    note "$rel: contains a repo-specific path or repo name"
  fi
done

[ $fail -eq 0 ] && echo "skill lint: OK"
exit $fail
