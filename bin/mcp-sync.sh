#!/usr/bin/env bash
# mcp-sync.sh: register every MCP server in ~/.agents/mcp/servers.json with each installed agent.
#
#   mcp-sync.sh              apply
#   mcp-sync.sh --dry-run    show what would change; writes nothing, calls no agent CLI
#   MCP_SYNC_AGENTS="claude devin" mcp-sync.sh     # only these agents
#                         (claude devin codex gemini cursor copilot)
#                         Servers removed from servers.json stay recorded until a full
#                         sync, so the agents left out are pruned then.
#
# Idempotent. It manages only the servers it created (names tracked in
# ~/.config/agents/mcp-managed.txt). Servers you added by hand in an agent are left
# alone, unless they have the same name as one in servers.json; servers.json wins.
set -euo pipefail

HUB="${AGENTS_HUB:-$HOME/.agents}"
SRC="$HUB/mcp/servers.json"
STATE_DIR="${AGENTS_STATE:-$HOME/.config/agents}"
STATE="$STATE_DIR/mcp-managed.txt"
BACKUP_DIR="${BACKUP_DIR:-/private/tmp/ai-setup-backup-$(date +%Y%m%d-%H%M%S)}"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

command -v jq >/dev/null 2>&1 || { echo "error: jq is required (brew install jq)" >&2; exit 1; }
[ -f "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }

# Expand a leading $HOME in every string; drop keys starting with "_" (used as comments).
RESOLVED="$(jq --arg home "$HOME" '
  walk(if type == "object" then with_entries(select(.key | startswith("_") | not))
       elif type == "string" then sub("^\\$HOME"; $home)
       else . end)' "$SRC")"

CURRENT="$(jq -r '.mcpServers // {} | keys[]' <<<"$RESOLVED")"
PREVIOUS=""; [ -f "$STATE" ] && PREVIOUS="$(cat "$STATE")"
REMOVED="$(comm -23 <(printf '%s\n' "$PREVIOUS" | sed '/^$/d' | sort -u) \
                  <(printf '%s\n' "$CURRENT"  | sed '/^$/d' | sort -u))"
REMOVED_JSON="$(printf '%s\n' "$REMOVED" | jq -R . | jq -s 'map(select(length > 0))')"

# Per-agent translations of one server entry (input: the entry from servers.json).
JQ_DEFS='
def kind: if has("command") then "stdio" else (.type // "http") end;
def stdio: {command, args: (.args // []), env: (.env // {})};
def to_claude: if kind == "stdio" then {type: "stdio"} + stdio
               else {type: kind, url, headers: (.headers // {})} end;
def to_devin:  if kind == "stdio" then stdio
               else {url, transport: kind, headers: (.headers // {})} end;
def to_gemini: if kind == "stdio" then stdio
               elif kind == "sse" then {url, headers: (.headers // {})}
               else {httpUrl: .url, headers: (.headers // {})} end;
def to_cursor: if kind == "stdio" then stdio
               else {url, headers: (.headers // {})} end;
def to_copilot: if kind == "stdio" then {type: "local"} + stdio + {tools: ["*"]}
                else {type: kind, url, headers: (.headers // {}), tools: ["*"]} end;
'

want() {   # want <agent> <cli> <config-dir>
  if [ -n "${MCP_SYNC_AGENTS:-}" ]; then
    case " $MCP_SYNC_AGENTS " in *" $1 "*) return 0 ;; *) return 1 ;; esac
  fi
  command -v "$2" >/dev/null 2>&1 || [ -d "$3" ]
}

backup_copy() {   # copy a file into BACKUP_DIR (same relative path) before changing it
  [ -f "$1" ] || return 0
  local dest="$BACKUP_DIR${1#$HOME}"
  mkdir -p "$(dirname "$dest")" && cp -p "$1" "$dest"
}

merge_json() {   # merge_json <label> <file> <translator>: for agents configured by a JSON file
  local label="$1" file="$2" fn="$3" current='{}' result
  [ -s "$file" ] && current="$(cat "$file")"
  result="$(jq --argjson src "$RESOLVED" --argjson removed "$REMOVED_JSON" "$JQ_DEFS
    .mcpServers = (
      ((.mcpServers // {}) | with_entries(select(.key as \$k | any(\$removed[]; . == \$k) | not)))
      + ((\$src.mcpServers // {}) | map_values($fn))
    )" <<<"$current")" ||
    { echo "error: could not build $file" >&2; return 1; }

  if [ "$DRY" = 1 ]; then
    echo "—— $label: $file would have mcpServers:"; jq '.mcpServers' <<<"$result"; return 0
  fi
  backup_copy "$file"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$result" > "$file.tmp.$$"
  cat "$file.tmp.$$" > "$file" && rm -f "$file.tmp.$$"   # keeps the file's permissions
  echo "updated: $label ($file)"
}

entry() { jq -c --arg n "$1" "$JQ_DEFS .mcpServers[\$n] | $2" <<<"$RESOLVED"; }

sync_claude() {   # via the claude CLI (never edit ~/.claude.json by hand)
  local n
  [ "$DRY" = 1 ] || backup_copy "$HOME/.claude.json"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if [ "$DRY" = 1 ]; then echo "—— claude: claude mcp remove -s user $n"; continue; fi
    claude mcp remove -s user "$n" >/dev/null 2>&1 || true
    echo "removed: claude ($n)"
  done <<<"$REMOVED"

  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if [ "$DRY" = 1 ]; then echo "—— claude: claude mcp add-json -s user $n '$(entry "$n" to_claude)'"; continue; fi
    claude mcp remove -s user "$n" >/dev/null 2>&1 || true
    claude mcp add-json -s user "$n" "$(entry "$n" to_claude)" >/dev/null
    echo "updated: claude ($n)"
  done <<<"$CURRENT"
}

sync_codex() {   # via the codex CLI (config is TOML)   (verify flags with: codex mcp add --help)
  local n kv a
  [ "$DRY" = 1 ] || backup_copy "$HOME/.codex/config.toml"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if [ "$DRY" = 1 ]; then echo "—— codex: codex mcp remove $n"; continue; fi
    codex mcp remove "$n" >/dev/null 2>&1 || true
    echo "removed: codex ($n)"
  done <<<"$REMOVED"

  while IFS= read -r n; do
    [ -n "$n" ] || continue
    local cmd=(codex mcp add "$n")
    if [ "$(entry "$n" kind)" = '"stdio"' ]; then
      while IFS= read -r kv; do [ -n "$kv" ] && cmd+=(--env "$kv"); done \
        < <(jq -r --arg n "$n" '.mcpServers[$n].env // {} | to_entries[] | "\(.key)=\(.value)"' <<<"$RESOLVED")
      cmd+=(--)
      while IFS= read -r a; do cmd+=("$a"); done \
        < <(jq -r --arg n "$n" '.mcpServers[$n] | .command, (.args // [])[]' <<<"$RESOLVED")
    else
      cmd+=(--url "$(jq -r --arg n "$n" '.mcpServers[$n].url' <<<"$RESOLVED")")
    fi
    if [ "$DRY" = 1 ]; then printf '—— codex:'; printf ' %q' "${cmd[@]}"; echo; continue; fi
    codex mcp remove "$n" >/dev/null 2>&1 || true
    "${cmd[@]}" >/dev/null
    echo "updated: codex ($n)"
  done <<<"$CURRENT"
}

[ "$DRY" = 1 ] && echo "DRY RUN: nothing will be written" && echo "removed since last sync: $(printf '%s' "${REMOVED:-<none>}" | tr '\n' ' ')"

want claude  claude  "$HOME/.claude"        && sync_claude
want devin   devin   "$HOME/.config/devin" && merge_json devin   "$HOME/.config/devin/mcp_config.json" to_devin
want codex   codex   "$HOME/.codex"         && sync_codex
want gemini  gemini  "$HOME/.gemini"        && merge_json gemini  "$HOME/.gemini/settings.json"        to_gemini
want cursor  cursor  "$HOME/.cursor"        && merge_json cursor  "$HOME/.cursor/mcp.json"              to_cursor
want copilot copilot "$HOME/.copilot"       && merge_json copilot "$HOME/.copilot/mcp-config.json"      to_copilot

if [ "$DRY" = 0 ]; then
  mkdir -p "$STATE_DIR"
  if [ -n "${MCP_SYNC_AGENTS:-}" ] && [ -n "$REMOVED" ]; then
    printf '%s\n%s\n' "$CURRENT" "$REMOVED" | sed '/^$/d' | sort -u > "$STATE"
    echo "note: partial sync; removed servers $(printf '%s' "$REMOVED" | tr '\n' ' ') are pruned from the other agents on the next full sync"
  else
    printf '%s\n' "$CURRENT" > "$STATE"
  fi
  [ -d "$BACKUP_DIR" ] && echo "backups in: $BACKUP_DIR (macOS clears /private/tmp on reboot)"
fi

echo "done."
