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

  # Frontmatter is name and description only: the subset every host reads.
  extra="$(awk 'NR==1{next} /^---$/{exit} /^[A-Za-z_-]+:/{sub(/:.*/,""); print}' "$skill" \
           | grep -vxE 'name|description' || true)"
  [ -z "$extra" ] || note "$rel: frontmatter key(s) other hosts may reject: $(printf '%s' "$extra" | tr '\n' ' ')"
  desc_len="$(sed -n 's/^description: //p' "$skill" | head -1 | wc -c | tr -d ' ')"
  [ "$desc_len" -le 1025 ] || note "$rel: description longer than 1024 characters"

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

  # A skill named in backticks must exist, so a chain cannot call a stage that is not there.
  while read -r ref; do
    [ -n "$ref" ] || continue
    [ -d "$root/skills/${ref#/}" ] || note "$rel: names skill ${ref#/}, which does not exist"
  done < <(grep -oE '`/?android-[a-z-]+`' "$skill" | tr -d '`' | sort -u)

  # Repo-specific strings are configuration, not skill content.
  if grep -qE '/Users/|eplayment-pixel-android|eplayment-android|keri-android|mannypay-android' "$skill"; then
    note "$rel: contains a repo-specific path or repo name"
  fi
done

# Skills and shared files are host-neutral; host specifics live in shared/hosts.md only.
while read -r f; do
  rel="${f#"$root"/}"
  [ "$rel" = shared/hosts.md ] && continue
  hit="$(grep -nE 'Copilot|Claude Code|Codex|Gemini' "$f" | head -1 || true)"
  [ -z "$hit" ] || note "$rel:$hit — names a host; use shared/hosts.md"
  slash="$(grep -nE '(^|[ `(])/(android-[a-z-]+|ticket|bugfix)([^a-z-]|$)' "$f" | head -1 || true)"
  [ -z "$slash" ] || note "$rel:$slash — slash-invokes a workflow skill; name it in backticks instead"
done < <(find "$root/skills" "$root/shared" -name '*.md')
for s in ticket bugfix android-ship android-commit-push; do
  grep -q 'shared/rails-check.md' "$root/skills/$s/SKILL.md" || note "skills/$s/SKILL.md: does not run shared/rails-check.md"
done

# MCP servers. Copilot and Codex read mcp.json, Claude Code .mcp.json, Gemini its manifest. Each
# declares the Atlassian server by URL, never a credential — each developer signs in.
for f in mcp.json .mcp.json gemini-extension.json; do
  [ -e "$root/$f" ] || { note "$f: missing"; continue; }
  grep -q '"mcpServers"' "$root/$f" || note "$f: no mcpServers object"
  grep -q 'https://mcp.atlassian.com/v1/mcp' "$root/$f" || note "$f: does not declare the Atlassian server"
  grep -qiE '"(headers|env|authorization|token|apikey|api_key|password|secret)"' "$root/$f" \
    && note "$f: declares headers or credentials; each developer signs in instead"
done

# Manifests: one name everywhere, one version across the three manifests.
manifest_field() { sed -n -E "s/^[[:space:]]*\"$2\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" "$1" | head -1; }
for f in plugin.json .claude-plugin/plugin.json gemini-extension.json; do
  [ -e "$root/$f" ] || { note "$f: missing"; continue; }
  [ "$(manifest_field "$root/$f" name)" = android-workflow ] || note "$f: name is not android-workflow"
done
v="$(manifest_field "$root/plugin.json" version)"
for f in .claude-plugin/plugin.json gemini-extension.json; do
  [ -e "$root/$f" ] && [ "$(manifest_field "$root/$f" version)" != "$v" ] && note "$f: version differs from plugin.json ($v)"
done
for f in .claude-plugin/marketplace.json .agents/plugins/marketplace.json; do
  [ -e "$root/$f" ] || { note "$f: missing"; continue; }
  grep -q '"name": "android-workflow"' "$root/$f" || note "$f: does not list android-workflow"
done

# Hook wiring. Each event's matcher must name every tool that host uses to run a shell command or
# edit a file, or a rail is silently skipped there. One entry per event, matcher on its own line.
hj="$root/hooks/hooks.json"
matcher_of() { grep -A3 "\"$1\"" "$hj" | sed -n -E 's/.*"matcher": "([^"]*)".*/\1/p' | head -1; }
if [ -e "$hj" ]; then
  for t in Bash Edit Write MultiEdit apply_patch; do
    printf '%s' "|$(matcher_of PreToolUse)|" | grep -q "|$t|" || note "hooks/hooks.json: PreToolUse matcher misses $t"
  done
  for t in run_shell_command write_file replace; do
    printf '%s' "|$(matcher_of BeforeTool)|" | grep -q "|$t|" || note "hooks/hooks.json: BeforeTool matcher misses $t"
  done
  for t in Edit Write MultiEdit apply_patch; do
    printf '%s' "|$(matcher_of PostToolUse)|" | grep -q "|$t|" || note "hooks/hooks.json: PostToolUse matcher misses $t"
  done
  for t in write_file replace; do
    printf '%s' "|$(matcher_of AfterTool)|" | grep -q "|$t|" || note "hooks/hooks.json: AfterTool matcher misses $t"
  done
else
  note "hooks/hooks.json: missing"
fi
for f in "$hj" "$root/com.github.copilot/hooks/hooks.json"; do
  [ -e "$f" ] || continue
  while read -r ref; do
    [ -x "$root/$ref" ] || note "${f#"$root"/}: runs $ref, which is missing or not executable"
  done < <(grep -oE 'hooks/[a-z-]+\.sh' "$f" | sort -u)
done

[ $fail -eq 0 ] && echo "skill lint: OK"
exit $fail
