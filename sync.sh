#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_URL="${AI_CONTEXT_STRUCTURE_ARCHIVE_URL:-https://github-releases.eplayment.co/eplayment/ai-context-structure/latest.tar.gz}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGED_BLOCK_START="<!-- AI_CONTEXT_STRUCTURE:START -->"
MANAGED_BLOCK_HINT="- Read \`.github/ai-context-structure-instructions.md\` first and follow everything in it."

# The centrally managed AI context layers, and the whole of what sync may touch
# under .ai/. Must match MANAGED_AI_LAYERS in @eplayment/cli
# (src/aics/operations.js). Every other path under .ai/, including
# .ai/project/ and .ai/features/, is the project's own and is never written,
# overwritten, or deleted by a sync.
MANAGED_AI_LAYERS=(company department)

usage() {
  cat <<'USAGE'
Usage: sync.sh [copy|sync] [target_dir]

Commands:
  copy  First install. Download the latest archive into target_dir, including
        the .ai/project/ and .ai/features/ starting points.
  sync  Refresh the directory that contains sync.sh, or target_dir if provided.
        Replaces .ai/company/ and .ai/department/ wholesale and leaves every
        other path under .ai/ untouched.
USAGE
}

extract_archive() {
  local temp_dir="$1"
  # No member list. Archives have been published both with and without a
  # leading "./" on each path and GNU tar will not match one form against the
  # other, so naming members here makes extraction fail on whichever form the
  # current release does not use. Extracting everything works with both.
  curl -fsSL "${ARCHIVE_URL}" | tar -xzf - -C "${temp_dir}"

  if [[ ! -d "${temp_dir}/.ai" ]]; then
    echo "Archive contains no .ai directory; refusing to continue." >&2
    exit 1
  fi
}

layer_has_files() {
  local dir="$1"
  [[ -d "${dir}" ]] && [[ -n "$(find "${dir}" -type f -print -quit)" ]]
}

# Replace each managed layer wholesale: files removed upstream go away locally,
# which a plain copy would leave behind forever.
#
# A layer is only reset when the archive actually carries files for it. That is
# deliberate, and it is also the failure worth knowing about: a release that
# ships without .ai/company/ does not break a sync, it quietly stops managing
# that layer in every repository. Hence the warning rather than a silent skip.
# The release build gate in scripts/check-managed-layers.sh is what stops such
# an archive being published in the first place.
reset_managed_ai_layers() {
  local temp_dir="$1"
  local target_dir="$2"
  local layer source_layer

  for layer in "${MANAGED_AI_LAYERS[@]}"; do
    source_layer="${temp_dir}/.ai/${layer}"

    if ! layer_has_files "${source_layer}"; then
      echo "Warning: this release carries no .ai/${layer}. Leaving the local copy alone;" >&2
      echo "         that layer is NOT being centrally managed by this archive." >&2
      continue
    fi

    rm -rf "${target_dir}/.ai/${layer}"
    mkdir -p "${target_dir}/.ai/${layer}"
    cp -R "${source_layer}/." "${target_dir}/.ai/${layer}/"
    echo "Reset .ai/${layer}"
  done
}

# First install only: the project has no context of its own yet, so the
# starting points for .ai/project/ and .ai/features/ are written too. Sync
# never re-sends them.
install_ai_tree() {
  local temp_dir="$1"
  local target_dir="$2"

  mkdir -p "${target_dir}/.ai"
  cp -R "${temp_dir}/.ai/." "${target_dir}/.ai/"
}

merge_managed_file() {
  local source_file="$1"
  local target_file="$2"
  local merged_file="$3"

  if [[ -f "${target_file}" ]]; then
    if grep -Fq -- "${MANAGED_BLOCK_START}" "${target_file}" \
      || grep -Fq -- "${MANAGED_BLOCK_HINT}" "${target_file}"; then
      :
    else
      cat "${source_file}" > "${merged_file}"
      if [[ -s "${target_file}" ]]; then
        printf '\n\n' >> "${merged_file}"
        cat "${target_file}" >> "${merged_file}"
      fi
      mv "${merged_file}" "${target_file}"
    fi
  else
    cp "${source_file}" "${target_file}"
  fi
}

download_archive() {
  local target_dir="$1"
  local mode="${2:-sync}"
  local temp_dir
  cleanup_temp_dir() {
    if [[ -n "${temp_dir:-}" && -d "${temp_dir}" ]]; then
      rm -rf "${temp_dir}"
    fi
  }

  mkdir -p "${target_dir}"

  trap cleanup_temp_dir EXIT
  temp_dir="$(mktemp -d)"

  # Everything below runs only after a complete download and extraction. A
  # failed fetch exits here, under `set -o pipefail`, having changed nothing.
  extract_archive "${temp_dir}"

  mkdir -p "${target_dir}/.github"

  if [[ "${mode}" == "install" ]]; then
    install_ai_tree "${temp_dir}" "${target_dir}"
  else
    reset_managed_ai_layers "${temp_dir}" "${target_dir}"
  fi

  cp "${temp_dir}/sync.sh" "${target_dir}/sync.sh"
  cp "${temp_dir}/.github/ai-context-structure-instructions.md" \
     "${target_dir}/.github/ai-context-structure-instructions.md"

  merge_managed_file "${temp_dir}/.github/copilot-instructions.md" \
    "${target_dir}/.github/copilot-instructions.md" "${temp_dir}/copilot-instructions.merged.md"
  merge_managed_file "${temp_dir}/AGENTS.md" \
    "${target_dir}/AGENTS.md" "${temp_dir}/AGENTS.merged.md"
  merge_managed_file "${temp_dir}/CLAUDE.md" \
    "${target_dir}/CLAUDE.md" "${temp_dir}/CLAUDE.merged.md"

  chmod +x "${target_dir}/sync.sh"
  echo "Synced AI context into ${target_dir}"
}

ensure_copy_target_is_new() {
  local target_dir="$1"
  if [[ -e "${target_dir}/.ai" \
    || -e "${target_dir}/.github/copilot-instructions.md" \
    || -e "${target_dir}/.github/ai-context-structure-instructions.md" \
    || -e "${target_dir}/sync.sh" \
    || -e "${target_dir}/AGENTS.md" \
    || -e "${target_dir}/CLAUDE.md" ]]; then
    echo "copy can only run once for a target directory; use ./sync.sh sync ${target_dir} instead." >&2
    exit 1
  fi
}

run_sync() {
  local sync_target="$1"
  local temp_dir

  if [[ "${AI_CONTEXT_STRUCTURE_SELF_UPDATED:-0}" != "1" ]]; then
    mkdir -p "${sync_target}"
    temp_dir="$(mktemp -d)"

    curl -fsSL "${ARCHIVE_URL}" | tar -xzf - -C "${temp_dir}"

    cp "${temp_dir}/sync.sh" "${sync_target}/sync.sh"
    chmod +x "${sync_target}/sync.sh"
    rm -rf "${temp_dir}"

    AI_CONTEXT_STRUCTURE_SELF_UPDATED=1 exec "${sync_target}/sync.sh" sync "${sync_target}"
  fi

  download_archive "${sync_target}" sync
}

command="${1:-sync}"

if [[ $# -gt 0 ]]; then
  shift
fi

case "${command}" in
  copy)
    copy_target="${1:-$(pwd)}"
    ensure_copy_target_is_new "${copy_target}"
    download_archive "${copy_target}" install
    ;;
  sync)
    run_sync "${1:-${SCRIPT_DIR}}"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: ${command}" >&2
    usage >&2
    exit 1
    ;;
esac
