# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- Unix helpers in `putapin.sh`: project-key encoding, prior-session detection, `Resume prior session? (Y/n)` prompt (stderr, whitespace-tolerant, re-prompts on invalid input, aborts on EOF), TTY check
- Test harnesses: bats (run under bash and zsh) with a `claude` stub, and Pester for PowerShell
- GitHub Actions CI: ubuntu/macOS × bash/zsh, plus Windows × PowerShell 5.1/7
- Implementation plan, phases summary, and verified Claude Code facts (`docs/notes/claude-code-facts.md`)

### Changed

### Deprecated

### Removed

### Fixed

### Security
