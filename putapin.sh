# shellcheck shell=bash
# putapin — ask "Resume prior session? (Y/n)" when launching Claude Code.
# Source this file from ~/.zshrc or ~/.bashrc; do not execute it.

# Claude Code stores sessions under a key made by replacing every
# non-alphanumeric character of the absolute project path with '-'.
_putapin_project_key() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'
}

# True if Claude Code has at least one saved session for directory $1.
# Uses find rather than a glob: an unmatched glob is fatal in zsh (NOMATCH).
_putapin_has_session() {
  local dir
  dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$(_putapin_project_key "$1")"
  [ -d "$dir" ] || return 1
  [ -n "$(find "$dir" -maxdepth 1 -name '*.jsonl' -type f 2>/dev/null | head -n 1)" ]
}
