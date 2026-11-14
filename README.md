# putapin-mod

## Description

A small mod for the [Claude Code](https://claude.com/claude-code) CLI. When you start
`claude` in a directory where you've used Claude Code before, it asks:

```
Resume prior session? (Y/n)
```

- **Enter**, **y** or **yes** resumes the most recent conversation for this directory,
  exactly where you left it (`claude --continue`).
- **n** or **no** starts a fresh session, the same as plain `claude`.
- Anything else asks again. **Ctrl-C** at the prompt returns you to the shell without starting Claude.

Works in **zsh** and **bash** (macOS, Linux, WSL, Git Bash) and in **PowerShell 5.1 and 7+** on Windows.

## Installation

### macOS / Linux (zsh or bash)

```sh
git clone https://github.com/keithmackay/putapin-mod
cd putapin-mod
./install.sh
```

Then open a new terminal. The installer:

- copies `putapin.sh` to `~/.config/putapin/` (or `$XDG_CONFIG_HOME/putapin/`);
- adds a short, clearly marked block to the rc file for your login shell (`~/.zshrc`, honoring
  `$ZDOTDIR`, or `~/.bashrc`), and to the other shell's rc file only if it already exists.

Re-running `./install.sh` is safe and is also how you upgrade.

> **macOS + bash:** Terminal starts bash as a login shell, which reads `~/.bash_profile`,
> not `~/.bashrc`. Make sure your `~/.bash_profile` sources `~/.bashrc`.

### Windows (PowerShell)

```powershell
git clone https://github.com/keithmackay/putapin-mod
cd putapin-mod
.\windows\Install.ps1
```

Then open a new PowerShell window. The installer copies the mod to `%LOCALAPPDATA%\putapin\` and
adds a marked block to your profile for both Windows PowerShell 5.1 and PowerShell 7
(`Documents\WindowsPowerShell\profile.ps1` and `Documents\PowerShell\profile.ps1`, following
OneDrive redirection). Existing profiles keep their encoding and line endings.

PowerShell only loads profiles if the execution policy allows it. If the installer warns about
this, run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## Usage

Just run `claude`. You'll see the prompt only when **all** of these are true:

- you typed a bare `claude`, with no arguments (`claude -p "..."`, `claude --resume` and so on run
  exactly as normal);
- you're in an interactive terminal, so pipes and scripts never block on the prompt;
- Claude Code has a saved session for the current directory.

Otherwise the real `claude` starts right away, unchanged.

To skip the mod once, bypass the wrapper:

| Shell | Command |
|---|---|
| zsh / bash | `command claude` or `\claude` |
| PowerShell | `& (Get-Command claude -CommandType Application, ExternalScript \| Select-Object -First 1)` |

If you already have your own `claude` alias or function, putapin leaves it alone and prints a
warning when your shell starts.

## Uninstall

```sh
./uninstall.sh                  # macOS / Linux
```

```powershell
.\windows\Uninstall.ps1         # Windows
```

Each removes the block it added (your rc file or profile is restored exactly, and a
`.putapin.bak` copy is kept) and deletes the installed file. Open a new terminal afterwards.

## How it works

Claude Code hooks run after a session has already started and can't ask an interactive
question, so they can't switch to a different session. putapin therefore runs *before* Claude
Code: it defines a shell function named `claude` that checks for a saved session in
`~/.claude/projects/` (or `$CLAUDE_CONFIG_DIR`), asks the question, and then starts the real CLI
with or without `--continue`. It never uses `exec`, so quitting Claude returns you to the same
shell.

## Development

```sh
bats tests                      # bash
TEST_SHELL=zsh bats tests       # zsh
shellcheck putapin.sh install.sh uninstall.sh
pwsh -c 'Invoke-Pester tests/windows'
```

CI runs all of these on Ubuntu, macOS and Windows (PowerShell 5.1 and 7). See `docs/plans/` for
the design and implementation plan.

## License

MIT. See [LICENSE](LICENSE).
