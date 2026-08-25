#!/usr/bin/env bash
# Path resolution shared by the rather-than hooks. Definitions only — no side effects.

rt_plugin_root() {
  printf '%s' "${CLAUDE_PLUGIN_ROOT:-${CODEX_PLUGIN_ROOT:-${PLUGIN_ROOT:-}}}"
}

rt_store_root() {
  if [ -n "${RATHER_THAN_HOME:-}" ]; then
    printf '%s' "$RATHER_THAN_HOME"
    return 0
  fi
  if [ -d "$HOME/.claude/rather-than" ]; then
    printf '%s' "$HOME/.claude/rather-than"
    return 0
  fi
  printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/rather-than"
}

rt_skill_scripts() {
  local plugin_root candidate
  plugin_root="$(rt_plugin_root)"
  for candidate in \
    "${plugin_root:+$plugin_root/skills/rather-than/scripts}" \
    "$HOME/.claude/skills/rather-than/scripts" \
    "$HOME/.agents/skills/rather-than/scripts" \
    "${CODEX_HOME:-$HOME/.codex}/skills/rather-than/scripts"; do
    if [ -n "$candidate" ] && [ -d "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  printf '%s' "$HOME/.claude/skills/rather-than/scripts"
}

rt_project_root() {
  local repo_root="$1"
  if [ -d "$repo_root/.claude/rather-than" ]; then
    printf '%s' "$repo_root/.claude/rather-than"
    return 0
  fi
  printf '%s' "$repo_root/.rather-than"
}
