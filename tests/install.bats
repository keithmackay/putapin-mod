#!/usr/bin/env bats
# Tests for install.sh / uninstall.sh. Everything runs against a fake $HOME.
load helpers

BEGIN_MARK='# >>> putapin >>>'

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  unset XDG_CONFIG_HOME ZDOTDIR
  export SHELL=/bin/zsh
  # Safety net: never let these tests touch a real home directory.
  case "$HOME" in "$BATS_TEST_TMPDIR"/*) ;; *) echo "unsafe HOME: $HOME" >&2; return 1 ;; esac
  INSTALLED="$HOME/.config/putapin/putapin.sh"
}

block_count() {
  grep -cF "$BEGIN_MARK" "$1"
}

# --- install.sh -------------------------------------------------------------

@test "install: copies the mod into ~/.config/putapin" {
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  cmp "$REPO/putapin.sh" "$INSTALLED"
}

@test "install: honors XDG_CONFIG_HOME" {
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg"
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  cmp "$REPO/putapin.sh" "$XDG_CONFIG_HOME/putapin/putapin.sh"
  [ ! -e "$INSTALLED" ]
}

@test "install: creates .zshrc for a zsh user" {
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [ "$(block_count "$HOME/.zshrc")" -eq 1 ]
}

@test "install: creates .bashrc (not .zshrc) for a bash user" {
  export SHELL=/bin/bash
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [ "$(block_count "$HOME/.bashrc")" -eq 1 ]
  [ ! -e "$HOME/.zshrc" ]
}

@test "install: also configures an existing rc for the other shell" {
  echo 'export FOO=1' > "$HOME/.bashrc"
  run "$REPO/install.sh"
  [ "$(block_count "$HOME/.bashrc")" -eq 1 ]
  [ "$(block_count "$HOME/.zshrc")" -eq 1 ]
}

@test "install: does not create an rc for the other shell" {
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.bashrc" ]
}

@test "install: honors ZDOTDIR for .zshrc" {
  export ZDOTDIR="$BATS_TEST_TMPDIR/zdot"
  mkdir -p "$ZDOTDIR"
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [ "$(block_count "$ZDOTDIR/.zshrc")" -eq 1 ]
  [ ! -e "$HOME/.zshrc" ]
}

@test "install: preserves existing rc content" {
  printf 'export FOO=1\nalias ll="ls -l"\n' > "$HOME/.zshrc"
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [ "$(head -n 2 "$HOME/.zshrc")" = "$(printf 'export FOO=1\nalias ll="ls -l"')" ]
}

@test "install: is idempotent" {
  "$REPO/install.sh"
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [ "$(block_count "$HOME/.zshrc")" -eq 1 ]
  assert_output_contains "Already configured"
}

@test "install: re-running refreshes an outdated installed copy" {
  "$REPO/install.sh"
  echo '# old version' > "$INSTALLED"
  run "$REPO/install.sh"
  cmp "$REPO/putapin.sh" "$INSTALLED"
}

@test "install: works when run from another directory" {
  cd /
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  cmp "$REPO/putapin.sh" "$INSTALLED"
}

@test "install: zsh rc block defines the wrapper" {
  "$REPO/install.sh"
  run zsh -f -c ". '$HOME/.zshrc'; whence -w claude"
  [ "$output" = "claude: function" ]
}

@test "install: bash rc block defines the wrapper" {
  export SHELL=/bin/bash
  "$REPO/install.sh"
  run bash -c ". '$HOME/.bashrc'; type -t claude"
  [ "$output" = "function" ]
}

@test "install: works with spaces in the home path" {
  export HOME="$BATS_TEST_TMPDIR/my home"
  mkdir -p "$HOME"
  run "$REPO/install.sh"
  [ "$status" -eq 0 ]
  run zsh -f -c ". '$HOME/.zshrc'; whence -w claude"
  [ "$output" = "claude: function" ]
}

@test "install: shell still starts if the installed file is deleted" {
  "$REPO/install.sh"
  rm "$INSTALLED"
  run zsh -f -c ". '$HOME/.zshrc'; echo ok"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "install: a symlinked rc stays a symlink" {
  mkdir -p "$HOME/dotfiles"
  echo 'export FOO=1' > "$HOME/dotfiles/zshrc"
  ln -s "$HOME/dotfiles/zshrc" "$HOME/.zshrc"
  run "$REPO/install.sh"
  [ -L "$HOME/.zshrc" ]
  [ "$(block_count "$HOME/dotfiles/zshrc")" -eq 1 ]
}

# --- uninstall.sh -----------------------------------------------------------

@test "uninstall: removes the block from both rc files" {
  echo 'export FOO=1' > "$HOME/.bashrc"
  "$REPO/install.sh"
  run "$REPO/uninstall.sh"
  [ "$status" -eq 0 ]
  refute_file_contains "$BEGIN_MARK" "$HOME/.zshrc"
  refute_file_contains "$BEGIN_MARK" "$HOME/.bashrc"
  refute_file_contains 'putapin.sh' "$HOME/.zshrc"
}

@test "uninstall: round trip leaves the rc byte-for-byte unchanged" {
  printf 'export FOO=1\n\nalias ll="ls -l"\n' > "$HOME/.zshrc"
  cp "$HOME/.zshrc" "$BATS_TEST_TMPDIR/original"
  "$REPO/install.sh"
  run "$REPO/uninstall.sh"
  [ "$status" -eq 0 ]
  cmp "$BATS_TEST_TMPDIR/original" "$HOME/.zshrc"
}

@test "uninstall: keeps content added after the block" {
  echo 'export FOO=1' > "$HOME/.zshrc"
  "$REPO/install.sh"
  echo 'export BAR=2' >> "$HOME/.zshrc"
  run "$REPO/uninstall.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.zshrc")" = "$(printf 'export FOO=1\nexport BAR=2')" ]
}

@test "uninstall: writes a .putapin.bak backup" {
  "$REPO/install.sh"
  cp "$HOME/.zshrc" "$BATS_TEST_TMPDIR/installed-rc"
  run "$REPO/uninstall.sh"
  cmp "$BATS_TEST_TMPDIR/installed-rc" "$HOME/.zshrc.putapin.bak"
}

@test "uninstall: deletes the installed file and its empty directory" {
  "$REPO/install.sh"
  run "$REPO/uninstall.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$INSTALLED" ]
  [ ! -e "$HOME/.config/putapin" ]
}

@test "uninstall: keeps the directory if it holds other files" {
  "$REPO/install.sh"
  touch "$HOME/.config/putapin/notes.txt"
  run "$REPO/uninstall.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$INSTALLED" ]
  [ -e "$HOME/.config/putapin/notes.txt" ]
}

@test "uninstall: honors XDG_CONFIG_HOME and ZDOTDIR" {
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" ZDOTDIR="$BATS_TEST_TMPDIR/zdot"
  mkdir -p "$ZDOTDIR"
  "$REPO/install.sh"
  run "$REPO/uninstall.sh"
  [ "$status" -eq 0 ]
  refute_file_contains "$BEGIN_MARK" "$ZDOTDIR/.zshrc"
  [ ! -e "$XDG_CONFIG_HOME/putapin/putapin.sh" ]
}

@test "uninstall: a symlinked rc stays a symlink" {
  mkdir -p "$HOME/dotfiles"
  echo 'export FOO=1' > "$HOME/dotfiles/zshrc"
  ln -s "$HOME/dotfiles/zshrc" "$HOME/.zshrc"
  "$REPO/install.sh"
  run "$REPO/uninstall.sh"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]
  [ "$(cat "$HOME/dotfiles/zshrc")" = "export FOO=1" ]
}

@test "uninstall: is a no-op when not installed" {
  echo 'export FOO=1' > "$HOME/.zshrc"
  run "$REPO/uninstall.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.zshrc")" = "export FOO=1" ]
  [ ! -e "$HOME/.zshrc.putapin.bak" ]
}

@test "uninstall: shell no longer defines the wrapper" {
  "$REPO/install.sh"
  "$REPO/uninstall.sh"
  run zsh -f -c ". '$HOME/.zshrc'; whence -w claude"
  [ "$output" != "claude: function" ]
}
