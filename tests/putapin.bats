#!/usr/bin/env bats
load helpers

setup() { setup_env; }

@test "harness: mod sources cleanly" {
  run_in_shell "true"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
