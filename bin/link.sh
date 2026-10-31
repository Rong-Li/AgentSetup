#!/usr/bin/env bash
# Link.sh: wire ~/.agents (the hub) into every installed AI coding agent.
# Idempotent: safe to re-run after adding skills or installing a new agent.
# Never overwrites real files without backing them up; never touches org-managed dirs.
set -euo pipefail

HUB="${AGENTS_HUB:-$HOME/.agents}"
RULES="$HUB/AGENTS.md"
BACKUP_DIR="${BACKUP_DIR:-/private/tmp/ai-setup-backup-$(date +%Y%m%d-%H%M%S)}"

[ -f "$RULES" ] || { echo "error: $RULES not found" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

backup() {
  local path="$1" dest="$BACKUP_DIR${1#$HOME}"
  mkdir -p "$(dirname "$dest")"
  mv "$path" "$dest"
  echo "backed up: $path -> $dest"
}

link_file() {
  local target="$1" link="$2"
  mkdir -p "$(dirname "$link")"

  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    echo "ok:      $link"
    return
  fi

  if [ -e "$link" ] || [ -L "$link" ]; then
    backup "$link"
  fi

  ln -sfn "$target" "$link"
  echo "linked:  $link -> $target"
}

link_skills() {
  local src_root="$1" dst_root="$2"
  [ -d "$src_root" ] || return 0
  mkdir -p "$dst_root"

  for src in "$src_root"/*; do
    [ -d "$src" ] || continue
    name="$(basename "$src")"
    dst="$dst_root/$name"

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      echo "skip:    $dst is a real folder (remove it if the hub copy should win)" >&2
      continue
    fi

    ln -sfn "$src" "$dst"
    echo "linked:  $dst -> $src"
  done
}

prune_links() {
  local dir="$1"
  [ -d "$dir" ] || return 0

  find "$dir" -maxdepth 1 -type l | while read -r l; do
    case "$(readlink "$l")" in
      "$HUB"/*)
        [ -e "$l" ] || { rm "$l"; echo "pruned: $l"; }
        ;;
    esac
  done
}

# 1. Claude Code: real CLAUDE.md that imports the hub (never a symlink).
if has claude || [ -d "$HOME/.claude" ]; then
  mkdir -p "$HOME/.claude"
  CMD="$HOME/.claude/CLAUDE.md"

  if [ -L "$CMD" ]; then
    backup "$CMD"
  fi

  if [ ! -e "$CMD" ]; then
    printf '@~/.agents/AGENTS.md\n\n# Claude Code only\n' > "$CMD"
    echo "created: $CMD"
  elif ! grep -qF '@~/.agents/AGENTS.md' "$CMD"; then
    echo "NOTE: add the line @~/.agents/AGENTS.md to the top of $CMD yourself" >&2
  else
    echo "ok:      $CMD"
  fi

  link_skills "$HUB/skills" "$HOME/.claude/skills"
  prune_links "$HOME/.claude/skills"
fi

# 2. Devin CLI + Devin Desktop
if has devin || [ -d "$HOME/.config/devin" ]; then
  link_file "$RULES" "$HOME/.config/devin/AGENTS.md"
fi

# 3. Codex CLI
if has codex || [ -d "$HOME/.codex" ]; then
  link_file "$RULES" "$HOME/.codex/AGENTS.md"
fi

# 4. Gemini CLI
if has gemini || [ -d "$HOME/.gemini" ]; then
  link_file "$RULES" "$HOME/.gemini/AGENTS.md"
  # Uncomment if Gemini does not list ~/.agents/skills natively:
  # link_skills "$HUB/skills" "$HOME/.gemini/skills"
fi

# 5. Copilot CLI
if has copilot || [ -d "$HOME/.copilot" ]; then
  link_file "$RULES" "$HOME/.copilot/copilot-instructions.md"
fi

# 6. Cursor: user rules are UI-only; paste ~/.agents/AGENTS.md into Settings -> Rules.

[ -d "$BACKUP_DIR" ] && \
  echo "backups in: $BACKUP_DIR (macOS clears /private/tmp on reboot)"
echo "done."
