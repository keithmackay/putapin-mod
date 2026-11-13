# Shared setup for putapin bats tests.
# TEST_SHELL selects the shell under test (bash | zsh). Defaults to bash.

PUTAPIN="$BATS_TEST_DIRNAME/../putapin.sh"

setup_env() {
  TEST_SHELL="${TEST_SHELL:-bash}"
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/claude-config"
  mkdir -p "$CLAUDE_CONFIG_DIR/projects"
  export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  mkdir -p "$BATS_TEST_TMPDIR/work"
  WORKDIR="$(cd "$BATS_TEST_TMPDIR/work" && pwd -P)"
  STDIN_FILE="$BATS_TEST_TMPDIR/stdin"
  : > "$STDIN_FILE"
}

# make_session <project-key>: create a fake prior session for that key.
make_session() {
  mkdir -p "$CLAUDE_CONFIG_DIR/projects/$1"
  touch "$CLAUDE_CONFIG_DIR/projects/$1/00000000-0000-0000-0000-000000000000.jsonl"
}

# workdir_key: the project key for $WORKDIR, computed independently of the mod.
workdir_key() {
  printf '%s' "$WORKDIR" | tr -c 'A-Za-z0-9' '-'
}

# type_input <text>: what the "user" types. Use '\n' for Enter. Empty = immediate EOF.
type_input() {
  printf '%b' "$1" > "$STDIN_FILE"
}

# run_in_shell <code>: source the mod in $TEST_SHELL inside $WORKDIR and run <code>.
run_in_shell() {
  local flags=()
  [ "$TEST_SHELL" = zsh ] && flags=(-f)
  run "$TEST_SHELL" "${flags[@]}" -c "cd '$WORKDIR' && . '$PUTAPIN' && $1" < "$STDIN_FILE"
}

# run_interactive <code>: same, but pretend we are on a TTY.
run_interactive() {
  run_in_shell "_putapin_is_interactive() { return 0; }; $1"
}
