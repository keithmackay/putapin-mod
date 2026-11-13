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
