# shellcheck shell=bash
# putapin — ask "Resume prior session? (Y/n)" when launching Claude Code.
# Source this file from ~/.zshrc or ~/.bashrc; do not execute it.

# Claude Code stores sessions under a key made by replacing every
# non-alphanumeric character of the absolute project path with '-'.
_putapin_project_key() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'
}
