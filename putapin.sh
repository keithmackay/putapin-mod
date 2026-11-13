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

# Prompt (on stderr) until we get an answer.
# Returns 0 = resume, 1 = fresh, 130 = aborted (EOF).
# read's default IFS trims surrounding whitespace, so " y " counts as y.
_putapin_ask() {
  local reply
  while :; do
    printf 'Resume prior session? (Y/n) ' >&2
    if ! read -r reply; then
      printf '\n' >&2
      return 130
    fi
    case "$reply" in
      ''|[Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo]) return 1 ;;
    esac
  done
}
