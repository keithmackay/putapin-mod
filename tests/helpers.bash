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

# run_raw <code>: like run_in_shell, but does NOT source the mod first.
run_raw() {
  local flags=()
  [ "$TEST_SHELL" = zsh ] && flags=(-f)
  run "$TEST_SHELL" "${flags[@]}" -c "cd '$WORKDIR' && $1" < "$STDIN_FILE"
}

# run_interactive <code>: same, but pretend we are on a TTY.
run_interactive() {
  run_in_shell "_putapin_is_interactive() { return 0; }; $1"
}

# Assertions. Use these instead of bare [[ ]]: under bash 3.2 (macOS /bin/bash)
# a failing [[ ]] that is not the last line of a test does NOT fail the test.
assert_output_contains() {
  [[ "$output" == *"$1"* ]] && return 0
  printf 'expected output to contain: %s\nactual output: %s\n' "$1" "$output" >&2
  return 1
}

refute_output_contains() {
  [[ "$output" != *"$1"* ]] && return 0
  printf 'expected output NOT to contain: %s\nactual output: %s\n' "$1" "$output" >&2
  return 1
}

assert_output_ends_with() {
  [[ "$output" == *"$1" ]] && return 0
  printf 'expected output to end with: %s\nactual output: %s\n' "$1" "$output" >&2
  return 1
}

# refute_file_contains <text> <file>. Use instead of `! grep`: bash's set -e
# ignores negated commands, so `! grep` mid-test never fails the test.
refute_file_contains() {
  if grep -qF -- "$1" "$2"; then
    printf 'expected %s NOT to contain: %s\n' "$2" "$1" >&2
    return 1
  fi
}
