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
