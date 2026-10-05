#!/usr/bin/env bash
# ============================================================================
# PreCompact — archive the transcript before it is summarised.
#
# Compaction is lossy, and the things it loses first (a decision and its
# reasoning, an unresolved bug, a rejected approach) are exactly what the
# learnings record is for. Keep the full transcript so nothing is gone for good.
# Best-effort; never interferes.
# ============================================================================
set -uo pipefail

INPUT="$(cat)"
read -r TRANSCRIPT CWD < <(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get("transcript_path","") or "-", d.get("cwd","") or "-")
except Exception: print("- -")' 2>/dev/null)

[ "$TRANSCRIPT" = "-" ] || [ ! -f "$TRANSCRIPT" ] && exit 0
[ "$CWD" = "-" ] && exit 0

DEST="$CWD/.claude/archive"
mkdir -p "$DEST" 2>/dev/null || exit 0
cp "$TRANSCRIPT" "$DEST/$(date +%Y%m%d-%H%M%S)-$(basename "$TRANSCRIPT")" 2>/dev/null || true

# Keep the last 20 archives; this is a safety net, not a data store.
ls -1t "$DEST"/*.jsonl 2>/dev/null | tail -n +21 | xargs -r rm -f 2>/dev/null || true
exit 0
