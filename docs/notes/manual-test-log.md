# Manual Test Log

Checklist from plan Task 6.3. "Stub" means `tests/stubs/claude` was first on `PATH`, so the
check shows *what would be launched* (`ARGS:...`) without opening the real Claude Code TUI.
Everything else used the real `claude` binary and the real `~/.claude` session store.

## 2026-11-14 — macOS (Darwin 25.5.0), Claude Code 2.1.292, run by Claude

Installed for real with `./install.sh` (approved by Keith). Pre-install `~/.zshrc` SHA-256:
`3e58e3bed73d416a4c9a84f08eaf1e07f60cb00b912622d50969b57d43ebdb00`.
Prompt checks ran in a real pseudo-terminal (`script -q /dev/null ...`) with timed input.

| # | Check | zsh 5.9 | bash 3.2 | How |
|---|---|---|---|---|
| 1 | No prior session → no prompt | ✅ | — | real store, scratch dir: `_putapin_has_session` false |
| 3 | Enter resumes | ✅ | — | stub: `ARGS:--continue` |
| 4 | `n` (as `"  N  "`) starts fresh | ✅ | — | stub: `ARGS:` |
| 5 | `maybe` → re-prompt → `y` resumes | ✅ | ✅ | stub: two prompts, then `ARGS:--continue` |
| – | `maybe` → EOF launches nothing, exit 130 | ✅ | — | stub |
| 7 | `claude --version` → no prompt | ✅ | — | real binary: `2.1.292 (Claude Code)` |
| 8 | Piped stdin → no prompt | ✅ | — | real binary: `echo \| claude --version` (not `-p`, to avoid an API call) |
| 10 | cwd via symlink → prompt appears | ✅ | — | stub, real store, symlink to this repo |
| – | cwd via wrong-case path (`~/projects/...`) → prompt appears | ✅ | — | real store; `pwd -P` normalizes case |
| – | Full real `~/.zshrc` loads cleanly; `claude` is a function; `cc` alias untouched | ✅ | — | `zsh -i` |

### Left for Keith (need the real interactive TUI)

Open a **new** terminal (so `~/.zshrc` loads putapin), then:

| # | Step | Expected | Result |
|---|---|---|---|
| 1 | `mkdir ~/putapin-try && cd ~/putapin-try && claude` | no prompt; fresh session | |
| 2 | Type `remember the word PINEAPPLE`, then `/exit` | back at the shell | |
| 3 | `claude`, press **Enter** at `Resume prior session? (Y/n)`; ask `what word?` | earlier conversation visible; answers PINEAPPLE | |
| 4 | `/exit`, then `claude`, answer `n` | fresh session, no earlier messages | |
| 5 | `/exit`, then `claude`, answer `maybe`, then `y` | asked again; then resumed | |
| 6 | `claude`, press **Ctrl-C** at the prompt | back at the shell; Claude did not start; tab still open | |
| 9 | After any resumed session, `/exit` | same shell, same tab (proves no `exec`) | |
| bash | `bash`, then `. ~/.config/putapin/putapin.sh`, then repeat step 3 | same as zsh | |

Clean up afterwards with `rm -r ~/putapin-try` if you like.

## Windows — pending (Keith; needs a Windows machine)

Task 5.4 first (see `docs/notes/claude-code-facts.md`), then run `.\windows\Install.ps1` and the
same steps in PowerShell 7 and Windows PowerShell 5.1.
