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

  # Referenced files must exist: shared/* at the plugin root, others beside the skill.
  while read -r ref; do
    [ -n "$ref" ] || continue
    [ -e "$root/$ref" ] || note "$rel: references missing file $ref"
  done < <(grep -oE 'shared/[A-Za-z0-9_-]+\.md' "$skill" | sort -u)

  # reference.md is the only skill-local file a SKILL.md may point at by bare name; anything else
  # with a path (.ai/project/conventions.md, say) belongs to the repository, not the plugin.
  if grep -q '`reference\.md`' "$skill" && [ ! -e "$dir/reference.md" ]; then
    note "$rel: points at reference.md, which does not exist beside it"
  fi

  # Relative escapes proved ambiguous in practice: the model miscounts the levels.
  grep -q '\.\./' "$skill" && note "$rel: uses a ../ path; name the plugin root instead"

  # Repo-specific strings are configuration, not skill content.
  if grep -qE '/Users/|eplayment-pixel-android|eplayment-android|keri-android|mannypay-android' "$skill"; then
    note "$rel: contains a repo-specific path or repo name"
  fi
done

[ $fail -eq 0 ] && echo "skill lint: OK"
exit $fail
