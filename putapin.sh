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

# True when both stdin and stdout are terminals. Kept separate so tests can
# override it (bats never has a TTY).
_putapin_is_interactive() {
  [ -t 0 ] && [ -t 1 ]
}

# What `claude` currently is in this shell: alias, function, file/command, or empty.
_putapin_claude_kind() {
  if [ -n "${ZSH_VERSION:-}" ]; then
    whence -w claude 2>/dev/null | sed 's/^claude: //'
  else
    type -t claude 2>/dev/null
  fi
}

# True if the current `claude` function is ours (from an earlier source of
# this file). Checks the body, so a wrapper defined after us is not mistaken
# for ours. typeset -f works in both bash and zsh.
_putapin_owns_claude() {
  typeset -f claude 2>/dev/null | grep -q '_putapin_ask'
}

# Never clobber someone else's alias or function; redefining our own is fine.
_putapin_install=1
case "$(_putapin_claude_kind)" in
  alias)
    _putapin_install=0
    printf "putapin: 'claude' is already an alias; not installing the resume prompt.\n" >&2
    ;;
  function)
    if ! _putapin_owns_claude; then
      _putapin_install=0
      printf "putapin: 'claude' is already a function; not installing the resume prompt.\n" >&2
    fi
    ;;
esac

# The wrapper. Prompts only for a bare `claude` in a terminal when this
# directory has a prior session; otherwise behaves exactly like the real CLI.
# Uses `command claude`, never exec: exec would replace the user's shell.
# Defined with the `function` keyword because `claude()` would be
# alias-expanded at parse time when an alias exists, even in an unrun branch.
if [ "$_putapin_install" = 1 ]; then
  function claude {
    if [ "$#" -gt 0 ] || ! _putapin_is_interactive || ! _putapin_has_session "$(pwd -P)"; then
      command claude "$@"
      return
    fi
    _putapin_ask
    case $? in
      0) command claude --continue ;;
      1) command claude ;;
      *) return 130 ;;
    esac
  }
fi
unset _putapin_install
