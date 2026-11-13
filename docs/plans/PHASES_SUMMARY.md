# putapin-mod — Phases Summary

Quick reference for [`2026-11-12-putapin-implementation-plan.md`](2026-11-12-putapin-implementation-plan.md).
The detailed plan is authoritative; this file must stay in sync with it.

## Current Status

| Phase | Title | Status |
|---|---|---|
| 0 | Tooling & Test Harness | ✅ Complete |
| 1 | Unix Core Helpers | 🟨 In Progress |
| 2 | Unix Dispatcher (`claude` function) | 🔲 Not Started |
| 3 | Unix Installer / Uninstaller | 🔲 Not Started |
| 4 | PowerShell Mod | 🔲 Not Started |
| 5 | Windows Installer / Uninstaller | 🔲 Not Started |
| 6 | Docs, Manual Verification, Release | 🔲 Not Started |

Legend: 🔲 Not Started · 🟨 In Progress · ✅ Complete

**Decided 2026-11-12:** shell code is measured by a branch checklist (every decision-flow branch tested
under bash and zsh) instead of 80% line coverage. Keith signed off.

**Phase 0 notes:** CI installs Pester 6.x (`-MinimumVersion 5.5` resolves to latest). The Homebrew
`powershell` formula failed to install (flaky .NET bottle download), so local `pwsh` uses Microsoft's
official osx-arm64 tarball instead; the local install is still pending and is only needed from Phase 4.

---

## Phase 0 — Tooling & Test Harness
**Goal:** working empty harnesses for bats (bash + zsh) and Pester, plus CI, so every later phase is pure red/green.

Tasks:
1. Install bats-core, shellcheck, PowerShell 7, Pester 5
2. Verify Claude Code facts (`--continue`, storage path, project-key encoding, physical path) → `docs/notes/claude-code-facts.md`
3. `tests/stubs/claude` stub that prints `ARGS:<argv>`
4. `tests/helpers.bash` (temp `CLAUDE_CONFIG_DIR`, `make_session`, `type_input`, `run_in_shell`, `run_interactive`)
5. Smoke test: `putapin.sh` sources cleanly in bash and zsh
6. Pester harness: `windows/putapin.ps1` dot-sources cleanly
7. `.github/workflows/ci.yml`: ubuntu/macOS × bash/zsh, plus windows × PS 5.1/7

**Deliverables:** harnesses, stub, CI green on 6 jobs.

## Phase 1 — Unix Core Helpers
**Goal:** helper functions in `putapin.sh`, tested in both shells.

Tasks:
1. `_putapin_project_key` — non-alphanumeric → `-`
2. `_putapin_has_session` — any `*.jsonl` in `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<key>/` (uses `find`, never a glob)
3. `_putapin_ask` — prompt loop; 0 yes / 1 no / 130 EOF; garbage re-prompts
4. `_putapin_is_interactive` — `[ -t 0 ] && [ -t 1 ]` (test seam)

**Deliverables:** helpers with full branch tests, shellcheck clean.

## Phase 2 — Unix Dispatcher
**Goal:** a `claude()` function that implements the decision flow.

Tasks:
1. Pass-through tests: args, non-TTY, no session
2. Prompting tests: Enter/y resume (`--continue`), n fresh, EOF → 130 with nothing launched, exit status propagated
3. Symlinked cwd uses `pwd -P`; implement `claude()` with `command claude`, **never `exec`**
4. Existing-alias guard: warn and don't define
5. Re-sourcing is safe

**Deliverables:** working zsh/bash mod.

## Phase 3 — Unix Installer / Uninstaller
**Goal:** idempotent `install.sh` / `uninstall.sh`, tested against a fake `$HOME`.

Tasks:
1. Install tests (copy, XDG, rc for `$SHELL`, existing other rc, idempotent, upgrade, harmless if file removed)
2. Implement `install.sh` (marked `# >>> putapin >>>` block with `[ -f ] &&` guard)
3. Uninstall tests and `uninstall.sh` (sed range delete, `.putapin.bak` backup, remove file/dir)

**Deliverables:** `install.sh`, `uninstall.sh`, `tests/install.bats`.

## Phase 4 — PowerShell Mod
**Goal:** `windows/putapin.ps1` behaving the same, compatible with PS 5.1.

Tasks:
1. `ConvertTo-PutapinProjectKey`
2. `Test-PutapinSession` (honors `CLAUDE_CONFIG_DIR`)
3. `Read-PutapinLine` (seam) + `Read-PutapinAnswer` → yes/no/abort
4. `Test-PutapinInteractive`, `Get-PutapinRealClaude` (Application/ExternalScript only)
5. `claude` function (uses the FileSystem provider path)

**Deliverables:** PowerShell mod plus Pester suite, green in CI on PS 5.1 and PS 7.

## Phase 5 — Windows Installer / Uninstaller
**Goal:** `Install.ps1` / `Uninstall.ps1` with injectable `-InstallDir` and `-ProfilePaths`.

Tasks:
1. Install tests (copy, create profiles, single block, idempotent, policy warning mocked)
2. Implement `Install.ps1` (LOCALAPPDATA, profile.ps1 for both PS 5.1 and PS 7, Unblock-File, warn but don't change the execution policy)
3. Uninstall tests and `Uninstall.ps1` (regex block removal, backup)
4. Manually verify the Windows project-key encoding on a real machine

**Deliverables:** Windows installers, verified key encoding.

## Phase 6 — Docs, Manual Verification, Release
**Goal:** ship v0.1.0.

Tasks:
1. README: install, usage, uninstall, how it works
2. MIT LICENSE
3. 10-step manual checklist on macOS zsh/bash and Windows PS 7/5.1 → `docs/notes/manual-test-log.md`
4. CHANGELOG 0.1.0, tag, push, `gh release create`

**Deliverables:** documented, tagged release.

---

## Technology Stack

- POSIX-ish shell with `local` (bash 3.2+ and zsh 5+): `putapin.sh`, `install.sh`, `uninstall.sh`
- PowerShell 5.1 / 7+: `windows/*.ps1`
- Tests: bats-core ≥ 1.5 (run under bash and zsh), Pester 5
- Lint: shellcheck
- CI: GitHub Actions (ubuntu, macOS, windows)
- Host: Claude Code CLI (`claude --continue`; sessions in `~/.claude/projects/<key>/*.jsonl`)

## Key Principles

- **TDD:** red → green → refactor → commit, every task.
- **YAGNI:** no config files, no fish/cmd, no previews in v1.
- **DRY:** one decision flow, shared by both platforms. One bats suite runs under both shells.
- Never touch the real `~/.claude` in tests. Never `exec` in the wrapper.

## Success Criteria

- A bare `claude` with history prompts the question. Enter/Y resumes, n starts fresh, garbage re-prompts, Ctrl-C/EOF launches nothing.
- No prompt when there are args, no TTY, or no history for the physical cwd.
- Works in zsh, bash, PS 5.1, PS 7. Installers are idempotent and reversible.
- CI green everywhere. Manual checklist passed.

## Post-Launch Maintenance

- Main risk: Claude Code changes its storage layout, key encoding, or the `--continue` flag. Re-run plan Task 0.2 after major Claude Code upgrades.
- Optionally add a weekly CI job that checks `claude --help` still lists `--continue`.
- Run shellcheck and both test suites on every change.
