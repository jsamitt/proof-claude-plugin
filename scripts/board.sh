#!/usr/bin/env bash
# ============================================================================
# board.sh — GitHub Projects helper for the Proof harness.
#
# Every value comes from .claude/harness.json. Nothing here knows the name of
# any project, field or stage.
#
#   source scripts/board.sh
#   board_init                      # resolve project from board.name
#   ITEM=$(board_item 14)           # item id, adding the issue if needed
#   board_set "$ITEM" "In Dev"      # set board.field to a stage value
#   board_archive "$ITEM"           # off the board (closed without shipping)
#
# Every function returns non-zero and prints to stderr on failure rather than
# exiting — board bookkeeping must never kill a run that is doing real work.
# ============================================================================

PROOF_CFG="${PROOF_CFG:-.claude/harness.json}"

_cfg() {  # _cfg <dotted.path> [default]
  python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print(sys.argv[3] if len(sys.argv) > 3 else ""); sys.exit(0)
for k in sys.argv[2].split("."):
    if isinstance(d, dict) and k in d and d[k] is not None:
        d = d[k]
    else:
        print(sys.argv[3] if len(sys.argv) > 3 else ""); sys.exit(0)
print(d if not isinstance(d, (dict, list)) else json.dumps(d))
' "$PROOF_CFG" "$1" "${2-}" 2>/dev/null
}

board_enabled() { [ "$(_cfg board.enabled false)" = "True" ] || [ "$(_cfg board.enabled false)" = "true" ]; }

# ---------------------------------------------------------------------------
# board_init — resolve PROOF_PROJECT_NUMBER / _ID / _OWNER / _FIELD
# ---------------------------------------------------------------------------
board_init() {
  [ -f "$PROOF_CFG" ] || { echo "board: no $PROOF_CFG — run /proof-init first" >&2; return 1; }
  board_enabled || { echo "board: disabled in config (labels still apply)" >&2; return 1; }

  local name; name="$(_cfg board.name)"
  [ -n "$name" ] || { echo "board: board.name not set in $PROOF_CFG" >&2; return 1; }

  PROOF_PROJECT_OWNER="$(gh repo view --json owner -q '.owner.login' 2>/dev/null)"
  [ -n "$PROOF_PROJECT_OWNER" ] || { echo "board: not a GitHub repo, or gh not authenticated" >&2; return 1; }

  local match
  match="$(gh project list --owner "$PROOF_PROJECT_OWNER" --format json 2>/dev/null \
    | python3 -c '
import json, sys
name = sys.argv[1]
hits = [p for p in json.load(sys.stdin).get("projects", []) if p.get("title") == name]
if len(hits) == 1:
    print(hits[0]["number"], hits[0]["id"])
elif len(hits) > 1:
    sys.stderr.write("board: %d projects titled %r — rename so it is unique\n" % (len(hits), name))
' "$name" 2>&1)" || true

  case "$match" in
    board:*) echo "$match" >&2; return 1 ;;
    "") echo "board: no project titled '$name' — run scripts/setup-board.sh" >&2; return 1 ;;
  esac

  PROOF_PROJECT_NUMBER="${match%% *}"
  PROOF_PROJECT_ID="${match##* }"
  PROOF_FIELD="$(_cfg board.field Status)"
  export PROOF_PROJECT_OWNER PROOF_PROJECT_NUMBER PROOF_PROJECT_ID PROOF_FIELD
}

# ---------------------------------------------------------------------------
# board_item <issue-number> — print the item id, adding the issue if absent
# ---------------------------------------------------------------------------
board_item() {
  local n="$1" id
  [ -n "${PROOF_PROJECT_NUMBER:-}" ] || { echo "board: call board_init first" >&2; return 1; }

  id="$(gh project item-list "$PROOF_PROJECT_NUMBER" --owner "$PROOF_PROJECT_OWNER" \
        --limit 500 --format json 2>/dev/null \
    | python3 -c '
import json, sys
for i in json.load(sys.stdin).get("items", []):
    if (i.get("content") or {}).get("number") == int(sys.argv[1]):
        print(i["id"]); break
' "$n" 2>/dev/null)"

  if [ -z "$id" ]; then
    local url
    url="$(gh issue view "$n" --json url -q '.url' 2>/dev/null)" || {
      echo "board: issue #$n not found" >&2; return 1; }
    id="$(gh project item-add "$PROOF_PROJECT_NUMBER" --owner "$PROOF_PROJECT_OWNER" \
          --url "$url" --format json -q '.id' 2>/dev/null)" || {
      echo "board: could not add issue #$n to the board" >&2; return 1; }
  fi

  echo "$id"
}

# ---------------------------------------------------------------------------
# board_set <item-id> <option-name> — set board.field to a stage value
# ---------------------------------------------------------------------------
board_set() {
  local item="$1" option="$2" fields field_id option_id
  [ -n "${PROOF_PROJECT_NUMBER:-}" ] || { echo "board: call board_init first" >&2; return 1; }

  fields="$(gh project field-list "$PROOF_PROJECT_NUMBER" --owner "$PROOF_PROJECT_OWNER" \
            --format json 2>/dev/null)" || { echo "board: cannot read fields" >&2; return 1; }

  read -r field_id option_id <<<"$(printf '%s' "$fields" | python3 -c '
import json, sys
fname, oname = sys.argv[1], sys.argv[2]
for f in json.load(sys.stdin).get("fields", []):
    if f.get("name") == fname:
        for o in f.get("options", []):
            if o.get("name") == oname:
                print(f["id"], o["id"]); raise SystemExit
        sys.stderr.write("board: field %r has no option %r\n" % (fname, oname)); raise SystemExit(1)
sys.stderr.write("board: no field named %r\n" % fname); raise SystemExit(1)
' "$PROOF_FIELD" "$option" 2>&1)" || return 1

  [ -n "$field_id" ] && [ -n "$option_id" ] || { echo "board: could not resolve '$option'" >&2; return 1; }

  gh project item-edit --project-id "$PROOF_PROJECT_ID" --id "$item" \
    --field-id "$field_id" --single-select-option-id "$option_id" >/dev/null 2>&1 \
    || { echo "board: failed to set '$option'" >&2; return 1; }
}

# ---------------------------------------------------------------------------
# board_archive <item-id> — take an item off the board without deleting it.
# For issues closed without shipping (duplicate, superseded, not planned):
# GitHub's "Item closed" workflow would otherwise file them under the last
# stage as if they had shipped. Undo with: gh project item-archive --undo
# ---------------------------------------------------------------------------
board_archive() {
  local item="$1"
  [ -n "${PROOF_PROJECT_NUMBER:-}" ] || { echo "board: call board_init first" >&2; return 1; }
  [ -n "$item" ] || { echo "board: no item to archive" >&2; return 1; }

  gh project item-archive "$PROOF_PROJECT_NUMBER" --owner "$PROOF_PROJECT_OWNER" \
    --id "$item" >/dev/null 2>&1 \
    || { echo "board: failed to archive item $item" >&2; return 1; }
}

# ---------------------------------------------------------------------------
# board_stage <key> — map a config stage key to its display name
#   board_stage in_dev  ->  "In Dev"
# ---------------------------------------------------------------------------
board_stage() { _cfg "board.stages.$1"; }
