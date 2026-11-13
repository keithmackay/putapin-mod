#!/bin/sh
# Uninstall putapin: remove the rc-file blocks and the installed mod.
set -eu

DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/putapin"
BEGIN='# >>> putapin >>>'
END='# <<< putapin <<<'

# Remove the block from rc file $1, plus the blank line install.sh put before it.
# Writes back with `cat >` (not mv or sed -i) so symlinks and permissions survive.
remove_block() {
  rc=$1
  tmp="$rc.putapin.tmp"
  cp "$rc" "$rc.putapin.bak"
  awk -v begin="$BEGIN" -v end="$END" '
    $0 == begin { held = 0; skipping = 1; next }
    skipping    { if ($0 == end) skipping = 0; next }
    held        { print ""; held = 0 }
    $0 == ""    { held = 1; next }
                { print }
    END         { if (held) print "" }
  ' "$rc" > "$tmp"
  cat "$tmp" > "$rc"
  rm -f "$tmp"
  echo "Removed putapin from $rc (backup: $rc.putapin.bak)"
}

for rc in "${ZDOTDIR:-$HOME}/.zshrc" "$HOME/.bashrc"; do
  if [ -f "$rc" ] && grep -qF "$BEGIN" "$rc"; then
    remove_block "$rc"
  fi
done

rm -f "$DEST_DIR/putapin.sh"
rmdir "$DEST_DIR" 2>/dev/null || true
echo "Uninstalled. Open a new terminal to finish."
