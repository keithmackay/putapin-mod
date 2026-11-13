#!/bin/sh
# Install putapin: copy the mod into the config dir and source it from shell rc files.
# Safe to re-run; re-running is also how you upgrade.
set -eu

SRC_DIR=$(cd "$(dirname "$0")" && pwd)
DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/putapin"
DEST="$DEST_DIR/putapin.sh"
BEGIN='# >>> putapin >>>'
END='# <<< putapin <<<'

mkdir -p "$DEST_DIR"
cp "$SRC_DIR/putapin.sh" "$DEST"
echo "Installed $DEST"

# Append the source block to rc file $1 unless it is already there.
# Appending (>>) writes through symlinks, so dotfile-managed rc files stay links.
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

# Configure the rc file for the login shell (creating it if needed), plus the
# other shell's rc file if it already exists.
for name in zsh bash; do
  if [ "$name" = zsh ]; then rc="${ZDOTDIR:-$HOME}/.zshrc"; else rc="$HOME/.bashrc"; fi
  case "${SHELL:-}" in
    */"$name") add_block "$rc" ;;
    *) if [ -f "$rc" ]; then add_block "$rc"; fi ;;
  esac
done

echo "Done. Open a new terminal (or source your rc file) to activate."
