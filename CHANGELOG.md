# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- PowerShell mod (`windows/putapin.ps1`, PS 5.1 and 7+): same prompt and pass-through rules as zsh/bash, abort sets exit code 130, leaves an existing `claude` alias or third-party function untouched with a warning
- `install.sh` / `uninstall.sh`: idempotent; installs to `${XDG_CONFIG_HOME:-~/.config}/putapin/` and adds a guarded source block to `.zshrc` (honoring `ZDOTDIR`) and/or `.bashrc`; uninstall restores rc files byte-for-byte, keeps a `.putapin.bak`, and preserves symlinked rc files
- `claude` wrapper for zsh/bash: bare `claude` in a terminal with a prior session for the (physical) cwd prompts to resume (`--continue`) or start fresh; any arguments, non-TTY, or no prior session pass straight through; never `exec`s; leaves an existing `claude` alias or third-party function untouched with a warning
- Unix helpers in `putapin.sh`: project-key encoding, prior-session detection, `Resume prior session? (Y/n)` prompt (stderr, whitespace-tolerant, re-prompts on invalid input, aborts on EOF), TTY check
- Test harnesses: bats (run under bash and zsh) with a `claude` stub, and Pester for PowerShell
- GitHub Actions CI: ubuntu/macOS × bash/zsh, plus Windows × PowerShell 5.1/7
- Implementation plan, phases summary, and verified Claude Code facts (`docs/notes/claude-code-facts.md`)

### Changed

### Deprecated

### Removed

### Fixed

### Security
