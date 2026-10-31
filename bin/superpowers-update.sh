#!/usr/bin/env bash
# superpowers-update.sh: copy the Superpowers skills into the hub's shared skills folder.
# No plugin, no session-start hook: the skills are plain skills you invoke by name.
#
# Usage: superpowers-update.sh [--dry-run] <superpowers-dir>
# <superpowers-dir> is any copy of Superpowers that contains skills/: a git clone of
# github.com/obra/superpowers, an unzipped release, or an installed plugin folder.
#
# Only skills recorded in third_party/superpowers/skills.txt are ever replaced or
# removed. Your own skills in ~/.agents/skills are never touched.
# SUPERPOWERS_SKIP="name1 name2" leaves those skills out (and removes them if present).
set -euo pipefail

DRY=0
if [ "${1:-}" = "--dry-run" ]; then DRY=1; shift; fi
SRC="${1:?usage: superpowers-update.sh [--dry-run] <superpowers-dir>}"
SRC="${SRC%/}"
HUB="${AGENTS_HUB:-$HOME/.agents}"
SKILLS="$HUB/skills"
META="$HUB/third_party/superpowers"
LIST="$META/skills.txt"
SKIP="${SUPERPOWERS_SKIP:-} "

[ -d "$SRC/skills" ] || { echo "error: $SRC/skills not found" >&2; exit 1; }

VERSION=unknown
for m in package.json .claude-plugin/plugin.json .codex-plugin/plugin.json; do
  v=$(jq -r '.version // empty' "$SRC/$m" 2>/dev/null || true)
  if [ -n "$v" ]; then VERSION="$v"; break; fi
done

say() { if [ "$DRY" = 1 ]; then echo "would $*"; else echo "$*"; fi; }
in_list() { printf '%s\n' "$2" | grep -qxF "$1"; }

old=""
if [ -f "$LIST" ]; then old=$(cat "$LIST"); fi
new=""
[ "$DRY" = 1 ] || mkdir -p "$SKILLS"

for d in "$SRC"/skills/*/; do
  d="${d%/}"; name=$(basename "$d")
  [ -f "$d/SKILL.md" ] || continue
  case " $SKIP " in *" $name "*) continue ;; esac
  dst="$SKILLS/$name"
  if [ -e "$dst" ] && [ ! -L "$dst" ] && ! in_list "$name" "$old"; then
    echo "conflict: $dst exists and isn't from Superpowers; left alone" >&2; continue
  fi
  new="$new$name
"

  if [ -d "$dst" ] && [ ! -L "$dst" ] && diff -rq "$d" "$dst" >/dev/null 2>&1; then
    echo "ok:      $name"; continue
  fi
  if [ -d "$dst" ] || [ -L "$dst" ]; then say "update: $name"; else say "add:    $name"; fi
  if [ "$DRY" = 0 ]; then rm -rf "$dst"; cp -Rp "$d" "$dst"; fi
done

# Remove skills that came from Superpowers before but are gone upstream or now skipped
while IFS= read -r name; do
  case "$name" in ""|..|*/*) continue ;; esac
  in_list "$name" "$new" && continue
  if [ -e "$SKILLS/$name" ] || [ -L "$SKILLS/$name" ]; then
    say "remove: $name"
    [ "$DRY" = 1 ] || rm -rf "${SKILLS:?}/$name"
  fi
done <<EOF
$old
EOF

if [ "$DRY" = 1 ]; then
  echo "dry run: nothing written (Superpowers $VERSION from $SRC)"
  exit 0
fi

mkdir -p "$META"
printf '%s' "$new" > "$LIST"
echo "$VERSION" > "$META/VERSION"
if [ -f "$SRC/LICENSE" ]; then cp "$SRC/LICENSE" "$META/LICENSE"; fi
echo "Superpowers $VERSION: $(printf '%s' "$new" | grep -c .) skills in $SKILLS"
echo "next: git -C \"$HUB\" diff --stat, commit, then run bin/link.sh"
