# Verified Claude Code Facts

Facts the mod depends on. Re-verify after major Claude Code upgrades (plan Task 0.2).

## 2026-11-12 — Claude Code 2.1.292, macOS (Darwin 25.5.0)

- `claude --help` lists `-c, --continue`: "Continue the most recent conversation in the current directory".
- Sessions are stored as `~/.claude/projects/<project-key>/<session-uuid>.jsonl`
  (`$CLAUDE_CONFIG_DIR` replaces `~/.claude` when set).
- Project key = absolute path with every non-`[A-Za-z0-9]` character replaced by `-`
  (e.g. `/Users/keith.mackay/Projects/x` → `-Users-keith-mackay-Projects-x`; `.` and `_` become `-` too).
- The key uses the **physical** path: `cd /tmp` → `pwd -P` is `/private/tmp`, and
  `~/.claude/projects` contains 8 `-private-tmp-*` folders and 0 `-tmp-*` folders.
  The wrapper must use `pwd -P`, not `$PWD`.
- Windows key encoding (`C:\x\y` → `C--x-y`) is **not yet verified** — see plan Task 5.4.
