#!/usr/bin/env bats
load helpers

setup() { setup_env; }

@test "harness: mod sources cleanly" {
  run_in_shell "true"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- _putapin_project_key -------------------------------------------------

@test "project key: slashes become dashes" {
  run_in_shell "_putapin_project_key /Users/kim/proj"
  [ "$output" = "-Users-kim-proj" ]
}

@test "project key: dots, underscores, spaces become dashes" {
  run_in_shell "_putapin_project_key '/Users/k.m/my_proj x'"
  [ "$output" = "-Users-k-m-my-proj-x" ]
}

@test "project key: alphanumerics and dashes preserved" {
  run_in_shell "_putapin_project_key /a-B/c9"
  [ "$output" = "-a-B-c9" ]
}

# --- _putapin_has_session -------------------------------------------------

@test "has_session: true when a jsonl exists for the dir" {
  make_session "$(workdir_key)"
  run_in_shell "_putapin_has_session '$WORKDIR'"
  [ "$status" -eq 0 ]
}

@test "has_session: false when project folder is missing" {
  run_in_shell "_putapin_has_session '$WORKDIR'"
  [ "$status" -eq 1 ]
}

@test "has_session: false when folder has no jsonl" {
  mkdir -p "$CLAUDE_CONFIG_DIR/projects/$(workdir_key)"
  touch "$CLAUDE_CONFIG_DIR/projects/$(workdir_key)/notes.txt"
  run_in_shell "_putapin_has_session '$WORKDIR'"
  [ "$status" -eq 1 ]
}

@test "has_session: a session for a different dir does not count" {
  make_session "-some-other-dir"
  run_in_shell "_putapin_has_session '$WORKDIR'"
  [ "$status" -eq 1 ]
}

@test "has_session: uses HOME/.claude when CLAUDE_CONFIG_DIR unset" {
  local fakehome="$BATS_TEST_TMPDIR/home"
  mkdir -p "$fakehome/.claude/projects/$(workdir_key)"
  touch "$fakehome/.claude/projects/$(workdir_key)/s.jsonl"
  run_in_shell "unset CLAUDE_CONFIG_DIR; HOME='$fakehome'; _putapin_has_session '$WORKDIR'"
  [ "$status" -eq 0 ]
}

# --- _putapin_ask ---------------------------------------------------------
# Returns 0 = resume, 1 = fresh, 130 = aborted (EOF).

PROMPT='Resume prior session? (Y/n) '

prompt_count() {
  grep -o 'Resume prior session' <<<"$output" | wc -l | tr -d ' '
}

@test "ask: Enter means yes" {
  type_input '\n'
  run_in_shell "_putapin_ask"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$PROMPT"* ]]
}

@test "ask: y and Y mean yes" {
  for answer in y Y; do
    type_input "$answer\n"
    run_in_shell "_putapin_ask"
    [ "$status" -eq 0 ]
  done
}

@test "ask: yes in any case means yes" {
  for answer in yes YES YeS; do
    type_input "$answer\n"
    run_in_shell "_putapin_ask"
    [ "$status" -eq 0 ]
  done
}

@test "ask: n and N mean no" {
  for answer in n N; do
    type_input "$answer\n"
    run_in_shell "_putapin_ask"
    [ "$status" -eq 1 ]
  done
}

@test "ask: no in any case means no" {
  for answer in no NO No; do
    type_input "$answer\n"
    run_in_shell "_putapin_ask"
    [ "$status" -eq 1 ]
  done
}

@test "ask: surrounding whitespace is ignored" {
  type_input '  y \t\n'
  run_in_shell "_putapin_ask"
  [ "$status" -eq 0 ]
  type_input ' n  \n'
  run_in_shell "_putapin_ask"
  [ "$status" -eq 1 ]
}

@test "ask: whitespace-only answer means yes (default)" {
  type_input '   \n'
  run_in_shell "_putapin_ask"
  [ "$status" -eq 0 ]
  [ "$(prompt_count)" -eq 1 ]
}

@test "ask: garbage re-prompts until a valid answer" {
  type_input 'maybe\nyess\nn\n'
  run_in_shell "_putapin_ask"
  [ "$status" -eq 1 ]
  [ "$(prompt_count)" -eq 3 ]
}

@test "ask: EOF aborts" {
  type_input ''
  run_in_shell "_putapin_ask"
  [ "$status" -eq 130 ]
}

@test "ask: EOF after garbage aborts" {
  type_input 'x\n'
  run_in_shell "_putapin_ask"
  [ "$status" -eq 130 ]
  [ "$(prompt_count)" -eq 2 ]
}

@test "ask: prompt goes to stderr, not stdout" {
  type_input 'y\n'
  run_in_shell "_putapin_ask 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
