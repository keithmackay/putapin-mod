# putapin-mod — Implementation Plan

**Date:** 2026-11-12
**Status tracker:** [`PHASES_SUMMARY.md`](PHASES_SUMMARY.md) (keep its "Current Status" table up to date — `/next` reads it)

---

## 0. Read This First (Context for an Engineer With Zero Context)

### What we're building

A tiny "mod" for the **Claude Code CLI** (`claude`). When you type a bare `claude` in a
terminal, and a prior Claude Code conversation exists for the current directory, the mod asks:

```
Resume prior session? (Y/n)
```

- `Enter`, `y`, `yes` (any case) → runs `claude --continue` (Claude Code's built-in flag that
  reopens the most recent conversation for the current directory).
- `n`, `no` (any case) → runs plain `claude` (fresh session — identical to having no mod).
- Anything else → re-ask.
- Ctrl-C / EOF at the prompt → launch nothing, return to the shell.

### Why a shell wrapper and not a Claude Code hook/plugin

Claude Code `SessionStart` hooks run *after* a session has already been chosen and cannot read
interactive keyboard input in the TUI. A hook can't switch to another session. The only way to
get a *true* resume is to decide **before** Claude Code launches — i.e. a shell function named
`claude` that shadows the real binary and calls it with or without `--continue`. This was an
explicit design decision with Keith; don't revisit it without asking.

### Supported environments (v1)

| Platform | Shell | Mod file | Installer |
|---|---|---|---|
| macOS / Linux / WSL / Git Bash | zsh, bash | `putapin.sh` | `install.sh` / `uninstall.sh` |
| Windows | PowerShell 5.1 and 7+ | `windows/putapin.ps1` | `windows/Install.ps1` / `Uninstall.ps1` |

Out of scope (YAGNI): fish, cmd.exe, timeouts/auto-answer, session previews, config files.

### Facts about Claude Code you need (verified 2026-11-12, Claude Code 2.1.292)

1. **`claude --continue` / `-c`** — "Continue the most recent conversation in the current directory."
   Verify on your machine: `claude --help | grep -- --continue`.
2. **Session storage:** `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<project-key>/<session-uuid>.jsonl`.
3. **Project key:** the absolute directory path with **every character outside `[A-Za-z0-9]`
   replaced by `-`**. Examples:
   - `/Users/keith.mackay/Projects/putapin-mod` → `-Users-keith-mackay-Projects-putapin-mod`
   - `/private/tmp/x_y` → `-private-tmp-x-y`
   - `C:\Users\x\proj` → `C--Users-x-proj` (**expected — must be verified on Windows in Phase 5**)
4. **The path is the *physical* path** (symlinks resolved). On macOS, `cd /tmp` produces a key of
   `-private-tmp`, not `-tmp`. In shell, use `pwd -P`, **never** `$PWD`.

### Critical gotchas (read twice)

- **Never use `exec` in the wrapper.** It is a function in your interactive shell; `exec` would
  replace the shell and closing Claude would close the terminal tab. Use `command claude ...`.
- **`command claude`** bypasses shell functions and aliases and runs the real binary from `PATH`.
  This is also the user's escape hatch (`command claude` or `\claude`).
- **zsh `NOMATCH`:** in zsh, an unmatched glob like `dir/*.jsonl` is a fatal error by default.
  Don't glob for session files; use `find`.
- **Aliases:** if the user already has `alias claude=...`, defining `claude() {...}` in bash is a
  syntax error (alias expands at definition time). The mod must detect an existing alias, print a
  warning to stderr, and **not** define the function.
- **Tests must never touch the real `~/.claude`.** Always set `CLAUDE_CONFIG_DIR` to a temp dir.
- **zsh in tests:** run `zsh -f` (skip user rc files) so Keith's own `.zshrc` can't affect results.

### Tooling you'll use

| Tool | What | Install (macOS) | Docs |
|---|---|---|---|
| bats-core ≥ 1.5 | Bash test framework (`@test` blocks, `run`, `$status`, `$output`) | `brew install bats-core` | https://bats-core.readthedocs.io |
| shellcheck | Shell linter | `brew install shellcheck` | https://www.shellcheck.net |
| PowerShell 7 | To run Pester locally on a Mac | `brew install --formula powershell` | https://learn.microsoft.com/powershell |
| Pester 5 | PowerShell test framework (`Describe/It/Should/Mock`) | `pwsh -c 'Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser -Force'` | https://pester.dev |

### Testing approach

TDD is mandatory (see `CLAUDE.md` and `docs/TESTING_GUIDELINES.md`): write the failing test,
run it and **watch it fail**, write the minimum code, watch it pass, commit.

Key test-design ideas (please actually understand these — they're what make the tests trustworthy):

- **Stub binary.** `tests/stubs/claude` is a fake `claude` that prints `ARGS:<its arguments>` and
  exits. Tests put `tests/stubs` first on `PATH`, so `command claude` hits the stub. We assert on
  *exactly what would have been launched* — e.g. `ARGS:--continue` vs `ARGS:`.
- **Fake session store.** Each test gets its own `CLAUDE_CONFIG_DIR` under `$BATS_TEST_TMPDIR`,
  and creates (or doesn't) a `*.jsonl` in the right project-key folder.
- **TTY seam.** bats never has a TTY, so the mod's TTY check lives in its own function
  (`_putapin_is_interactive`) that tests redefine to `return 0`. One test leaves it alone to prove
  the non-interactive path.
- **One suite, two shells.** Every scenario runs via `$TEST_SHELL -c '...'`. CI runs the suite
  twice (`TEST_SHELL=bash`, `TEST_SHELL=zsh`).
- **Test behavior, not implementation.** Assert on outputs/exit codes, not on internal variables.
- **Each test is independent.** No ordering assumptions; `setup()` builds everything fresh.

**Coverage note:** shell code has no practical line-coverage tool in this stack (kcov is heavy and
flaky with zsh). Instead, coverage is a **branch checklist** — every branch of the decision flow
below has at least one test, under both shells. This is a deviation from the 80% line-coverage
target in `docs/TESTING_GUIDELINES.md` and **needs Keith's sign-off before Phase 1 starts.**

### Decision flow (the spec)

```
claude [args...]
 ├─ args given?                         → command claude "$@"        (no prompt)
 ├─ not interactive (stdin/stdout TTY)? → command claude             (no prompt)
 ├─ no *.jsonl for key(pwd -P)?         → command claude             (no prompt)
 └─ prompt loop
      ├─ "" | y | yes  (any case, whitespace trimmed) → command claude --continue
      ├─ n  | no       (any case)      → command claude
      ├─ EOF                           → print newline, return 130, launch nothing
      ├─ Ctrl-C                        → shell aborts the function, launch nothing
      └─ anything else                 → re-prompt
```

### Commit discipline

Commit after every green task (small commits). Message style: imperative, e.g.
`Add project-key encoding for session lookup`. End every commit message with:

```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

Push to `origin main` at the end of each phase (repo: https://github.com/keithmackay/putapin-mod).
Update `PHASES_SUMMARY.md` status (🔲 → 🟨 → ✅) as you go, and add a `CHANGELOG.md` entry under
`[Unreleased]` per phase.

---

## Phase 0 — Tooling & Test Harness

**Goal:** a working, empty test harness for both shell families and PowerShell, plus a CI skeleton,
so every later phase is pure red/green.

### Task 0.1 — Install local tools

```sh
brew install bats-core shellcheck
brew install --formula powershell
pwsh -NoProfile -c 'Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser -Force -SkipPublisherCheck'
bats --version          # expect 1.5+
shellcheck --version
pwsh -NoProfile -c 'Get-Module Pester -ListAvailable | Select Version'
```

No commit (nothing in repo changes).

### Task 0.2 — Verify the Claude Code assumptions

Run and record the results in `docs/notes/claude-code-facts.md` (create it):

```sh
claude --version
claude --help | grep -A1 -- '--continue'
ls "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects" | head
cd /tmp && pwd && pwd -P      # on macOS: /tmp vs /private/tmp
ls ~/.claude/projects | grep -- '-private-tmp' | head -3   # proves physical path is used
```

Commit: `Document verified Claude Code session-storage facts`.

### Task 0.3 — Stub binary

Create `tests/stubs/claude`:

```sh
#!/bin/sh
# Test double for the real Claude Code CLI: echoes what it was called with.
printf 'ARGS:%s\n' "$*"
```

`chmod +x tests/stubs/claude`. Sanity check: `tests/stubs/claude --continue` → `ARGS:--continue`;
`tests/stubs/claude` → `ARGS:`.

### Task 0.4 — bats helpers

Create `tests/helpers.bash`:

```bash
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
```

Note: `workdir_key` deliberately uses `tr`, a *different* implementation from the mod's `sed`, so
the test isn't just re-running the code under test.

### Task 0.5 — Harness smoke test

Create `putapin.sh` containing only a header comment:

```sh
# shellcheck shell=bash
# putapin — ask "Resume prior session? (Y/n)" when launching Claude Code.
# Source this file from ~/.zshrc or ~/.bashrc; do not execute it.
```

Create `tests/putapin.bats`:

```bash
#!/usr/bin/env bats
load helpers

setup() { setup_env; }

@test "harness: mod sources cleanly" {
  run_in_shell "true"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
```

Run `bats tests` and `TEST_SHELL=zsh bats tests` → both pass.
Commit: `Add bats test harness and claude stub`.

### Task 0.6 — Pester harness

Create `windows/putapin.ps1` with only a header comment:

```powershell
# putapin — ask "Resume prior session? (Y/n)" when launching Claude Code.
# Dot-source this file from your PowerShell profile.
```

Create `tests/windows/putapin.Tests.ps1`:

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\windows\putapin.ps1')
}

Describe 'harness' {
    It 'dot-sources cleanly' {
        $true | Should -BeTrue
    }
}
```

Run: `pwsh -NoProfile -c 'Invoke-Pester tests/windows -Output Detailed'` → passes.
(Use forward slashes or `Join-Path` everywhere so tests run on macOS pwsh too.)
Commit: `Add Pester test harness`.

### Task 0.7 — CI skeleton

Create `.github/workflows/ci.yml`:

```yaml
name: CI
on: [push, pull_request]

jobs:
  unix:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
        shell: [bash, zsh]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Install tools (Linux)
        if: runner.os == 'Linux'
        run: sudo apt-get update && sudo apt-get install -y bats zsh shellcheck
      - name: Install tools (macOS)
        if: runner.os == 'macOS'
        run: brew install bats-core shellcheck
      - run: bats --version
      - run: shellcheck putapin.sh install.sh uninstall.sh tests/stubs/claude
        if: hashFiles('install.sh') != ''
      - run: bats tests
        env:
          TEST_SHELL: ${{ matrix.shell }}

  windows:
    strategy:
      fail-fast: false
      matrix:
        ps: [pwsh, powershell]
    runs-on: windows-latest
    defaults:
      run:
        shell: ${{ matrix.ps }}
    steps:
      - uses: actions/checkout@v4
      - run: Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser -Force -SkipPublisherCheck
      - run: Invoke-Pester tests/windows -CI -Output Detailed
```

If `apt`'s bats is < 1.5 on the runner (check the `bats --version` step), switch to
`npm install -g bats`. Commit `Add CI workflow`, push, and confirm all 6 jobs go green on GitHub
(`gh run watch`).

**Phase 0 done when:** both harnesses pass locally and CI is green. Update PHASES_SUMMARY, CHANGELOG, push.

---

## Phase 1 — Unix Core Helpers

> **Decisions made at Phase 1 kickoff (Keith, 2026-11-12) — these supersede the code below:**
> - The prompt is written to **stderr**, not stdout.
> - Surrounding whitespace in answers is ignored (`" y "` = y, `"   "` = Enter). Implemented by
>   using `read -r reply` with the default IFS (no `IFS=`), which trims in both bash and zsh.
> - See `putapin.sh` and `tests/putapin.bats` for the as-built versions.

**Goal:** the three pure-ish helpers, fully tested in bash and zsh. All code goes in `putapin.sh`;
all tests in `tests/putapin.bats`. For every task: write tests → `bats tests` (fail) →
implement → `bats tests` and `TEST_SHELL=zsh bats tests` (pass) → `shellcheck putapin.sh` → commit.

### Task 1.1 — `_putapin_project_key`

Tests:

```bash
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
```

Implementation:

```sh
# Claude Code stores sessions under a key made by replacing every
# non-alphanumeric character of the absolute project path with '-'.
_putapin_project_key() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'
}
```

Commit: `Add project-key encoding for session lookup`.

### Task 1.2 — `_putapin_has_session`

Tests (cover: present, absent dir, dir with no jsonl, non-jsonl files only, CLAUDE_CONFIG_DIR
honored, default `$HOME/.claude` when unset):

```bash
@test "has_session: true when a jsonl exists for the dir" {
  make_session "$(workdir_key)"
  run_in_shell "_putapin_has_session '$WORKDIR'"
  [ "$status" -eq 0 ]
}

@test "has_session: false when project folder is missing" {
  run_in_shell "_putapin_has_session '$WORKDIR'"
  [ "$status" -ne 0 ]
}

@test "has_session: false when folder has no jsonl" {
  mkdir -p "$CLAUDE_CONFIG_DIR/projects/$(workdir_key)"
  touch "$CLAUDE_CONFIG_DIR/projects/$(workdir_key)/notes.txt"
  run_in_shell "_putapin_has_session '$WORKDIR'"
  [ "$status" -ne 0 ]
}

@test "has_session: uses HOME/.claude when CLAUDE_CONFIG_DIR unset" {
  local fakehome="$BATS_TEST_TMPDIR/home"
  mkdir -p "$fakehome/.claude/projects/$(workdir_key)"
  touch "$fakehome/.claude/projects/$(workdir_key)/s.jsonl"
  run_in_shell "unset CLAUDE_CONFIG_DIR; HOME='$fakehome'; _putapin_has_session '$WORKDIR'"
  [ "$status" -eq 0 ]
}
```

Implementation:

```sh
# True if Claude Code has at least one saved session for directory $1.
_putapin_has_session() {
  local dir
  dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$(_putapin_project_key "$1")"
  [ -d "$dir" ] || return 1
  [ -n "$(find "$dir" -maxdepth 1 -name '*.jsonl' -type f 2>/dev/null | head -n 1)" ]
}
```

(`find` instead of a glob because of zsh `NOMATCH` — see gotchas.)
Commit: `Detect prior Claude Code sessions for a directory`.

### Task 1.3 — `_putapin_ask`

Return codes: `0` = yes, `1` = no, `130` = abort (EOF). Tests — each one sets input with
`type_input`, then `run_in_shell "_putapin_ask"`:

| Test name | input | expect status | extra assertion |
|---|---|---|---|
| Enter means yes | `'\n'` | 0 | output contains `Resume prior session? (Y/n) ` |
| y means yes | `'y\n'` | 0 | |
| Y means yes | `'Y\n'` | 0 | |
| yes/YES/Yes means yes | `'YeS\n'` | 0 | |
| n means no | `'n\n'` | 1 | |
| N/no/NO means no | `'No\n'` | 1 | |
| garbage re-prompts | `'maybe\nn\n'` | 1 | prompt appears exactly twice |
| EOF aborts | `''` | 130 | |
| EOF after garbage aborts | `'x\n'` (no 2nd line) | 130 | |

Example:

```bash
@test "ask: garbage re-prompts until a valid answer" {
  type_input 'maybe\nn\n'
  run_in_shell "_putapin_ask"
  [ "$status" -eq 1 ]
  [ "$(grep -o 'Resume prior session' <<<"$output" | wc -l | tr -d ' ')" -eq 2 ]
}
```

Implementation:

```sh
# Prompt until we get an answer. Returns 0 = resume, 1 = fresh, 130 = aborted (EOF).
_putapin_ask() {
  local reply
  while :; do
    printf 'Resume prior session? (Y/n) '
    if ! IFS= read -r reply; then
      printf '\n'
      return 130
    fi
    case "$reply" in
      ''|[Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo]) return 1 ;;
    esac
  done
}
```

Note: zsh's `read` is not identical to bash's, but `IFS= read -r var` behaves the same in both.
The zsh run of the suite is what proves this.
Commit: `Add Resume prior session prompt loop`.

### Task 1.4 — `_putapin_is_interactive`

```sh
# Seam for tests: true when both stdin and stdout are terminals.
_putapin_is_interactive() {
  [ -t 0 ] && [ -t 1 ]
}
```

Test: `run_in_shell "_putapin_is_interactive"` → status non-zero (bats has no TTY). This is the
only automated test of the real function; the TTY-true path is covered by manual testing (Phase 6).
Commit: `Add interactive-terminal check`.

**Phase 1 done when:** all tests green in both shells, shellcheck clean. Update docs, push.

---

## Phase 2 — Unix Dispatcher (`claude` function)

> **As built (2026-11-13) — supersedes the code below where they differ:**
> - Keith decided an existing `claude` **function** (someone else's wrapper) gets the same treatment
>   as an alias: warn on stderr and don't install.
> - The wrapper is defined as `function claude { ... }`, **not** `claude() { ... }`. Shells
>   alias-expand `claude()` at *parse* time, so with an alias present the whole file failed to
>   parse (in both bash and zsh), even inside an un-run `else` branch.
> - "Is this function ours?" is decided by the function body (`typeset -f claude | grep -q
>   _putapin_ask`), not a flag variable, so a wrapper defined after putapin survives a re-source.
> - Guard tests use `run_raw` (doesn't pre-source the mod) and enable alias expansion.
> - **bats gotcha:** macOS `/bin/bash` is 3.2, where a failing `[[ ]]` that isn't the last line of a
>   test does NOT fail it. Use the `assert_output_contains` / `refute_output_contains` /
>   `assert_output_ends_with` helpers in `tests/helpers.bash`, never bare `[[ ]]`.

**Goal:** wire the helpers into the `claude()` function per the decision flow.

### Task 2.1 — Pass-through cases (write all tests first)

```bash
@test "dispatch: args pass straight through, no prompt" {
  make_session "$(workdir_key)"
  run_interactive "claude -p 'hello world'"
  [ "$status" -eq 0 ]
  [ "$output" = "ARGS:-p hello world" ]
}

@test "dispatch: non-interactive runs plain claude, no prompt" {
  make_session "$(workdir_key)"
  run_in_shell "claude"            # real _putapin_is_interactive → false under bats
  [ "$output" = "ARGS:" ]
}

@test "dispatch: no prior session runs plain claude, no prompt" {
  run_interactive "claude"
  [ "$output" = "ARGS:" ]
}
```

### Task 2.2 — Prompting cases

```bash
@test "dispatch: Enter resumes" {
  make_session "$(workdir_key)"; type_input '\n'
  run_interactive "claude"
  [[ "$output" == *"Resume prior session? (Y/n) "* ]]
  [[ "$output" == *"ARGS:--continue" ]]
}

@test "dispatch: n starts fresh" {
  make_session "$(workdir_key)"; type_input 'n\n'
  run_interactive "claude"
  [[ "$output" == *"ARGS:" ]]
  [[ "$output" != *"--continue"* ]]
}

@test "dispatch: EOF launches nothing and returns 130" {
  make_session "$(workdir_key)"; type_input ''
  run_interactive "claude"
  [ "$status" -eq 130 ]
  [[ "$output" != *"ARGS:"* ]]
}

@test "dispatch: exit status of real claude is propagated" {
  # make a stub that fails
  mkdir -p "$BATS_TEST_TMPDIR/failstub"
  printf '#!/bin/sh\nexit 7\n' > "$BATS_TEST_TMPDIR/failstub/claude"
  chmod +x "$BATS_TEST_TMPDIR/failstub/claude"
  make_session "$(workdir_key)"; type_input 'y\n'
  run_interactive "PATH='$BATS_TEST_TMPDIR/failstub':\$PATH; claude"
  [ "$status" -eq 7 ]
}
```

### Task 2.3 — Symlinked directory uses the physical path

```bash
@test "dispatch: symlinked cwd resolves to physical path" {
  ln -s "$WORKDIR" "$BATS_TEST_TMPDIR/link"
  make_session "$(workdir_key)"      # key of the *physical* dir
  type_input 'y\n'
  run "$TEST_SHELL" $([ "$TEST_SHELL" = zsh ] && echo -f) -c \
    "cd '$BATS_TEST_TMPDIR/link' && . '$PUTAPIN' && _putapin_is_interactive() { return 0; }; claude" < "$STDIN_FILE"
  [[ "$output" == *"ARGS:--continue" ]]
}
```

Run all → fail. Implement:

```sh
claude() {
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
```

Ctrl-C note: in an interactive bash/zsh, SIGINT during `read` aborts the whole function, so
nothing launches. This can't be exercised in bats; it is in the Phase 6 manual checklist.
Commit after green: `Add claude dispatcher with resume prompt`.

### Task 2.4 — Existing alias guard

Test:

```bash
@test "alias guard: existing claude alias is left alone with a warning" {
  run "$TEST_SHELL" $([ "$TEST_SHELL" = zsh ] && echo -f) -c \
    "alias claude='echo ALIASED'; . '$PUTAPIN'; type claude" < /dev/null
  [[ "$output" == *"putapin: 'claude' is already an alias"* ]]
  [[ "$output" == *"alias"* ]]
}
```

Note: bash only expands aliases in non-interactive shells with `shopt -s expand_aliases` — the
`type` check works regardless. Wrap the function definition:

```sh
if alias claude >/dev/null 2>&1; then
  printf "putapin: 'claude' is already an alias; not installing the resume prompt.\n" >&2
else
  claude() { ... }   # body from Task 2.3
fi
```

Commit: `Skip installing when claude is already aliased`.

### Task 2.5 — Re-sourcing is safe

Test: source the file twice, then run a prompting scenario → still works, no warnings.
(Should pass with no code change — if it doesn't, fix.) Commit: `Test that re-sourcing is safe`.

**Phase 2 done when:** full suite green under bash and zsh, shellcheck clean, CI green. Push.

---

## Phase 3 — Unix Installer / Uninstaller

> **As built (2026-11-13) — supersedes the code below where they differ:**
> - Keith chose **not** to run the installer on his real machine until Phase 6.
> - `.zshrc` location honors `ZDOTDIR` (`${ZDOTDIR:-$HOME}/.zshrc`) in both scripts.
> - `install.sh` uses `if [ -f "$rc" ]; then ...; fi`, not `[ -f "$rc" ] && ...`: under `set -e`
>   a false `&&` list as the loop's last command can make the script exit non-zero.
> - `uninstall.sh` does **not** use `sed -i`. It strips the block with `awk` (also dropping the
>   blank line `install.sh` adds before it, so install→uninstall is byte-for-byte) and writes back
>   with `cat tmp > "$rc"`, so symlinked (dotfile-managed) rc files stay symlinks. `sed -i` would
>   replace the symlink with a regular file and leave a stray blank line.
> - **bats gotcha #2:** bash's `set -e` ignores negated commands, so `! grep ...` mid-test never
>   fails. Use `refute_file_contains` from `tests/helpers.bash`.
> - Extra tests beyond the table: `SHELL=bash`, ZDOTDIR, preserved content, run-from-other-dir,
>   bash block works, spaces in `$HOME`, symlinked rc (install + uninstall), round trip, content
>   after the block, non-empty config dir kept. Mutation-checked: reverting to `mv` or the plan's
>   `sed -i` makes the round-trip/symlink tests fail.

**Goal:** `./install.sh` and `./uninstall.sh`, idempotent, tested against a fake `$HOME`.

New test file: `tests/install.bats`. Its setup:

```bash
setup() {
  REPO="$BATS_TEST_DIRNAME/.."
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  unset XDG_CONFIG_HOME
  export SHELL=/bin/zsh
}
```

### Task 3.1 — Install tests (write all first)

| Test | Arrange | Assert |
|---|---|---|
| copies mod | — | `$HOME/.config/putapin/putapin.sh` exists and `cmp`s equal to repo `putapin.sh` |
| honors XDG_CONFIG_HOME | `XDG_CONFIG_HOME=$BATS_TEST_TMPDIR/xdg` | file at `$XDG_CONFIG_HOME/putapin/putapin.sh` |
| creates rc for $SHELL | no `.zshrc` exists, SHELL=/bin/zsh | `.zshrc` created with block |
| configures existing other rc | `.bashrc` exists | `.bashrc` has block too |
| leaves absent other rc alone | SHELL=zsh, no `.bashrc` | `.bashrc` still absent |
| idempotent | run twice | `grep -c '# >>> putapin >>>' .zshrc` = 1 |
| upgrade refreshes file | modify installed copy, rerun | equals repo copy again |
| block actually works | `zsh -f -c '. ~/.zshrc; type claude'` | output says function |
| missing file is harmless | install, `rm` installed file, `zsh -f -c '. ~/.zshrc; echo ok'` | status 0, output `ok` |

### Task 3.2 — Implement `install.sh`

```sh
#!/bin/sh
# Install putapin: copy the mod into the config dir and source it from shell rc files.
set -eu

SRC_DIR=$(cd "$(dirname "$0")" && pwd)
DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/putapin"
DEST="$DEST_DIR/putapin.sh"
BEGIN='# >>> putapin >>>'
END='# <<< putapin <<<'

mkdir -p "$DEST_DIR"
cp "$SRC_DIR/putapin.sh" "$DEST"
echo "Installed $DEST"

add_block() {
  rc=$1
  if [ -f "$rc" ] && grep -qF "$BEGIN" "$rc"; then
    echo "Already configured: $rc"
    return
  fi
  {
    printf '\n%s\n' "$BEGIN"
    printf '[ -f "%s" ] && . "%s"\n' "$DEST" "$DEST"
    printf '%s\n' "$END"
  } >> "$rc"
  echo "Configured: $rc"
}

for name in zsh bash; do
  rc="$HOME/.${name}rc"
  case "${SHELL:-}" in
    */"$name") add_block "$rc" ;;
    *) [ -f "$rc" ] && add_block "$rc" ;;
  esac
done

echo "Done. Open a new terminal (or source your rc file) to activate."
```

`chmod +x install.sh`. Green → commit `Add Unix installer`.

### Task 3.3 — Uninstall tests, then `uninstall.sh`

Tests: removes block from both rc files; leaves other rc content intact (put `export FOO=1`
before and after the block and check both survive); writes `<rc>.putapin.bak`; deletes the
installed file and (if empty) its directory; running uninstall when not installed exits 0.

```sh
#!/bin/sh
# Uninstall putapin: remove the rc-file blocks and the installed mod.
set -eu

DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/putapin"

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -f "$rc" ] && grep -qF '# >>> putapin >>>' "$rc"; then
    sed -i.putapin.bak '/^# >>> putapin >>>$/,/^# <<< putapin <<<$/d' "$rc"
    echo "Removed putapin from $rc (backup: $rc.putapin.bak)"
  fi
done

rm -f "$DEST_DIR/putapin.sh"
rmdir "$DEST_DIR" 2>/dev/null || true
echo "Uninstalled. Open a new terminal to finish."
```

(`sed -i.suffix` with the suffix attached works on both GNU and BSD/macOS sed.)
Commit `Add Unix uninstaller`. Add `shellcheck install.sh uninstall.sh` to your local loop.

**Phase 3 done when:** both bats files green under bash and zsh, shellcheck clean, CI green. Push.

---

## Phase 4 — PowerShell Mod

**Goal:** `windows/putapin.ps1` with the same behavior, tested with Pester (locally on macOS
pwsh; in CI on Windows PS 5.1 + 7). Keep everything PS 5.1-compatible: no `??`, no ternary,
no `&&`, no `-AsHashtable` etc.

### Task 4.1 — `ConvertTo-PutapinProjectKey`

Tests:

```powershell
Describe 'ConvertTo-PutapinProjectKey' {
    It 'encodes a Windows path' {
        ConvertTo-PutapinProjectKey 'C:\Users\x\proj' | Should -Be 'C--Users-x-proj'
    }
    It 'encodes a Unix path' {
        ConvertTo-PutapinProjectKey '/Users/k.m/my_proj' | Should -Be '-Users-k-m-my-proj'
    }
}
```

```powershell
# Claude Code keys sessions by the project path with every non-alphanumeric character as '-'.
function ConvertTo-PutapinProjectKey([string]$Path) {
    $Path -creplace '[^A-Za-z0-9]', '-'
}
```

### Task 4.2 — `Test-PutapinSession`

Use Pester's `$TestDrive` for a fake config dir; set `$env:CLAUDE_CONFIG_DIR` in `BeforeEach`
and restore it in `AfterEach`. Tests: true with a jsonl, false with no folder, false with only
non-jsonl, falls back to `$HOME\.claude` when env var empty.

```powershell
function Test-PutapinSession([string]$Path) {
    $root = $env:CLAUDE_CONFIG_DIR
    if (-not $root) { $root = Join-Path $HOME '.claude' }
    $dir = Join-Path (Join-Path $root 'projects') (ConvertTo-PutapinProjectKey $Path)
    $hit = Get-ChildItem -LiteralPath $dir -Filter '*.jsonl' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    [bool]$hit
}
```

### Task 4.3 — `Read-PutapinLine` + `Read-PutapinAnswer`

`Read-PutapinLine` is the seam (tests `Mock` it). Use `Write-Host -NoNewline` +
`[Console]::ReadLine()` rather than `Read-Host`, because `Read-Host` appends `": "` to the prompt
and can't signal EOF.

Tests (mock `Read-PutapinLine` with a queue of answers — e.g.
`$script:answers = [System.Collections.Queue]::new(@('maybe','n'))` and
`Mock Read-PutapinLine { $script:answers.Dequeue() }`):

| answers | expect |
|---|---|
| `''` | `yes` |
| `'y'`, `'YES'` | `yes` |
| `'n'`, `'No'` | `no` |
| `'maybe','n'` | `no`, and `Should -Invoke Read-PutapinLine -Times 2 -Exactly` |
| `$null` (EOF) | `abort` |

```powershell
# Seam for tests. Returns $null on EOF.
function Read-PutapinLine {
    Write-Host -NoNewline 'Resume prior session? (Y/n) '
    [Console]::ReadLine()
}

# Returns 'yes', 'no', or 'abort'.
function Read-PutapinAnswer {
    while ($true) {
        $reply = Read-PutapinLine
        if ($null -eq $reply) { return 'abort' }
        switch -Regex ($reply) {
            '^(y|yes)?$' { return 'yes' }
            '^(n|no)$'   { return 'no' }
        }
    }
}
```

(`switch -Regex` is case-insensitive by default — that's what we want.)

### Task 4.4 — `Test-PutapinInteractive` and `Get-PutapinRealClaude`

```powershell
function Test-PutapinInteractive {
    -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected
}

# The real Claude Code CLI: claude.exe (native installer) or claude.ps1/claude.cmd (npm).
function Get-PutapinRealClaude {
    Get-Command claude -CommandType Application, ExternalScript -ErrorAction SilentlyContinue |
        Select-Object -First 1
}
```

Test for `Get-PutapinRealClaude`: create `$TestDrive/bin/claude.ps1`, prepend that dir to
`$env:PATH` (use `[IO.Path]::PathSeparator`), assert the returned `.Source` is that file, and that
it is **not** the `claude` function (`.CommandType -ne 'Function'`).

### Task 4.5 — `claude` function

Test setup: create stub `$TestDrive/bin/claude.ps1` containing `"ARGS:$($args -join ' ')"`, and
`Mock Get-PutapinRealClaude { Get-Command $stubPath }`, `Mock Test-PutapinInteractive { $true }`,
`Mock Test-PutapinSession { $true }`, `Mock Read-PutapinAnswer { 'yes' }` — override per test.

| Test | Override | Expect output |
|---|---|---|
| args pass through | — | `claude -p hi` → `ARGS:-p hi`; `Read-PutapinAnswer` invoked 0 times |
| non-interactive | Interactive → `$false` | `ARGS:`; no prompt |
| no session | Session → `$false` | `ARGS:`; no prompt |
| yes resumes | answer `yes` | `ARGS:--continue` |
| no fresh | answer `no` | `ARGS:` |
| abort launches nothing | answer `abort` | `$null` output |
| real claude missing | RealClaude → `$null` | writes an error containing `putapin` |
| uses provider path | `Mock Test-PutapinSession` with `-ParameterFilter`; check it received `(Get-Location -PSProvider FileSystem).ProviderPath` | |

```powershell
function claude {
    $real = Get-PutapinRealClaude
    if (-not $real) {
        Write-Error "putapin: could not find the real 'claude' on PATH."
        return
    }
    $here = (Get-Location -PSProvider FileSystem).ProviderPath
    if ($args.Count -gt 0 -or -not (Test-PutapinInteractive) -or -not (Test-PutapinSession $here)) {
        & $real @args
        return
    }
    switch (Read-PutapinAnswer) {
        'yes' { & $real --continue }
        'no'  { & $real }
    }
}
```

Commit after each task (`Add PowerShell project-key encoding`, etc.). Run Pester locally after
every change: `pwsh -NoProfile -c 'Invoke-Pester tests/windows -Output Detailed'`.

**Phase 4 done when:** Pester green locally and on both Windows CI jobs. Push.

---

## Phase 5 — Windows Installer / Uninstaller

**Goal:** `windows/Install.ps1` and `windows/Uninstall.ps1`, testable by parameter injection.

### Task 5.1 — Install tests

New file `tests/windows/Install.Tests.ps1`. Call the script with
`& $installScript -InstallDir "$TestDrive\inst" -ProfilePaths "$TestDrive\p1\profile.ps1","$TestDrive\p2\profile.ps1"`.

Tests: copies mod into InstallDir; creates missing profiles (and their parent dirs); appends one
block to each; idempotent (block count = 1 after two runs); existing profile content preserved;
re-run refreshes the copied mod; warns (via `Write-Warning`, capture with `3>&1`) when
`Get-ExecutionPolicy` is mocked to `Restricted`, and doesn't warn for `RemoteSigned`.
Dot-sourcing the generated profile in a child `pwsh -NoProfile -c` defines a `claude` function.

### Task 5.2 — Implement `Install.ps1`

```powershell
# Install putapin for Windows PowerShell 5.1 and PowerShell 7.
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'putapin'),
    [string[]]$ProfilePaths = @(
        (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\profile.ps1'),
        (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\profile.ps1')
    )
)
$ErrorActionPreference = 'Stop'
$begin = '# >>> putapin >>>'
$end   = '# <<< putapin <<<'

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$dest = Join-Path $InstallDir 'putapin.ps1'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'putapin.ps1') -Destination $dest -Force
if (Get-Command Unblock-File -ErrorAction SilentlyContinue) { Unblock-File -LiteralPath $dest }
Write-Host "Installed $dest"

foreach ($p in $ProfilePaths) {
    New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
    if ((Test-Path $p) -and (Select-String -LiteralPath $p -SimpleMatch $begin -Quiet)) {
        Write-Host "Already configured: $p"
        continue
    }
    $block = @('', $begin, "if (Test-Path '$dest') { . '$dest' }", $end)
    Add-Content -LiteralPath $p -Value $block -Encoding UTF8
    Write-Host "Configured: $p"
}

$policy = Get-ExecutionPolicy
if ($policy -in 'Restricted', 'AllSigned', 'Undefined') {
    Write-Warning "Execution policy is '$policy', so PowerShell profiles will not load. Fix with: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
}
Write-Host 'Done. Open a new PowerShell window to activate.'
```

Note: on non-Windows pwsh, `Get-ExecutionPolicy` returns `Unrestricted`, so the warning never
fires — tests must `Mock Get-ExecutionPolicy`. `Undefined` is included because on Windows client
SKUs an undefined effective policy means `Restricted`.

### Task 5.3 — Uninstall tests + `Uninstall.ps1`

Same parameters. Tests: block removed from each profile; surrounding content intact; backup
`profile.ps1.putapin.bak` written; installed file and empty dir removed; no-op when not installed.

```powershell
param( <same two params as Install.ps1> )
$ErrorActionPreference = 'Stop'
foreach ($p in $ProfilePaths) {
    if (-not (Test-Path $p)) { continue }
    $text = Get-Content -LiteralPath $p -Raw
    if ($text -notmatch '# >>> putapin >>>') { continue }
    Copy-Item -LiteralPath $p -Destination "$p.putapin.bak" -Force
    $text = $text -replace '(?ms)\r?\n?# >>> putapin >>>.*?# <<< putapin <<<\r?\n?', ''
    Set-Content -LiteralPath $p -Value $text -Encoding UTF8 -NoNewline
    Write-Host "Removed putapin from $p (backup: $p.putapin.bak)"
}
Remove-Item -LiteralPath (Join-Path $InstallDir 'putapin.ps1') -ErrorAction SilentlyContinue
if ((Test-Path $InstallDir) -and -not (Get-ChildItem $InstallDir)) { Remove-Item $InstallDir }
Write-Host 'Uninstalled. Open a new PowerShell window to finish.'
```

### Task 5.4 — Verify the Windows project-key assumption (manual, on a real Windows box)

On Windows with Claude Code installed: `cd C:\some\dir; claude` → send one message → quit →
`ls $HOME\.claude\projects`. Confirm the folder is named per `ConvertTo-PutapinProjectKey`
(expected `C--some-dir`). If it differs, **stop and tell Keith**, update the function and its
test, and record the finding in `docs/notes/claude-code-facts.md`.

**Phase 5 done when:** Pester green locally + both Windows CI jobs; Task 5.4 verified. Push.

---

## Phase 6 — Docs, Manual Verification, Release

### Task 6.1 — README

Fill in `README.md`:
- **Installation** — Unix: `git clone https://github.com/keithmackay/putapin-mod && cd putapin-mod && ./install.sh`.
  Windows: `git clone ...; cd putapin-mod; .\windows\Install.ps1` (mention execution policy).
  macOS bash note: login shells read `~/.bash_profile`; make sure it sources `~/.bashrc`.
- **Usage** — the prompt, the answers, the skip conditions (args / non-TTY / no session),
  escape hatch (`command claude`, `\claude`; PowerShell: `& (Get-Command claude -CommandType Application)`).
- **Uninstall** — `./uninstall.sh` / `.\windows\Uninstall.ps1`.
- **How it works** — one paragraph on why it's a shell wrapper (see §0).
- **License** — MIT.

### Task 6.2 — LICENSE

Add MIT `LICENSE` (copyright 2026 Keith MacKay).

### Task 6.3 — Manual verification checklist

Record results (date, OS, shell, Claude Code version, pass/fail) in `docs/notes/manual-test-log.md`.

On macOS zsh **and** bash, and on Windows PowerShell 7 **and** 5.1:

1. Fresh dir with no history: `claude` → no prompt, fresh session.
2. Send a message ("remember the word PINEAPPLE"), quit.
3. `claude` → prompt appears. Press Enter → previous conversation is shown; ask "what word?" → PINEAPPLE.
4. Quit. `claude` → `n` → fresh session (no prior messages).
5. Quit. `claude` → type `maybe` → re-prompted → `y` → resumed.
6. `claude` → Ctrl-C at prompt → back at shell, Claude did not start, terminal tab still open.
7. `claude --version` → no prompt.
8. `echo hi | claude -p` → no prompt.
9. Quit Claude normally after a resume → you're back in the same shell (proves no `exec`).
10. `cd` via a symlink to the dir (macOS: `/tmp/...`) → prompt still appears.

### Task 6.4 — Release

- `CHANGELOG.md`: move `[Unreleased]` entries to `## [0.1.0] - <date>`.
- CI green on all jobs.
- `git tag v0.1.0 && git push origin main --tags`
- `gh release create v0.1.0 --generate-notes`

Update PHASES_SUMMARY → all ✅.

---

## Success Criteria

- Bare `claude` in a directory with history prompts `Resume prior session? (Y/n)`; Enter/Y resumes
  via `--continue`, n starts fresh, garbage re-prompts, Ctrl-C/EOF launches nothing.
- No prompt for: any arguments, non-TTY, no history for the physical cwd.
- Works in zsh, bash, PowerShell 5.1, PowerShell 7.
- Installers/uninstallers are idempotent and reversible, and never break shell startup.
- CI green on ubuntu+macOS (bash, zsh) and windows (PS 5.1, 7). Manual checklist passed.

## Post-Launch Maintenance

- **Claude Code changes are the main risk.** If Anthropic changes the session-storage layout,
  the project-key encoding, or renames `--continue`, the no-session check or resume will break.
  Symptom: prompt never appears (storage change) or `--continue` errors (flag change). Re-run
  Task 0.2 against the new version and update `docs/notes/claude-code-facts.md`.
- Consider a scheduled CI job (weekly) that installs the latest `@anthropic-ai/claude-code` and
  asserts `claude --help` still lists `--continue`.
- Keep `putapin.sh` POSIX-ish + `local`; run shellcheck on every change.

---

## Next Steps (Future Enhancements)

- **[Claude's idea]** Show a one-line preview of the last session before asking
  (e.g. its first user message and "2h ago"), read from the newest `.jsonl`.
- **[Claude's idea]** `PUTAPIN_DEFAULT=n` / `PUTAPIN_DISABLE=1` environment variables to change the
  default answer or turn the prompt off temporarily.
- **[Claude's idea]** Offer a third choice, `(Y/n/p)`, where `p` opens Claude Code's own session picker (`claude --resume`).
- **[Claude's idea]** Auto-answer after a timeout (e.g. resume after 5s of no input).
- **[Claude's idea]** One-line installer: `curl -fsSL https://raw.githubusercontent.com/keithmackay/putapin-mod/main/install.sh | sh`
  (the installer would need to download `putapin.sh` when not run from a clone).
- **[Claude's idea]** fish shell support (`functions/claude.fish`).
- **[Claude's idea]** Homebrew tap / Scoop manifest for distribution.
- **[Claude's idea]** Skip the prompt when the last session is older than N days.
- **[Keith's idea]** Windows support was requested by Keith during design and is in v1 scope
  (Phases 4–5); extend it later to cmd.exe if there's demand.
