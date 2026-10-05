#!/usr/bin/env bash
# ============================================================================
# Stop — verification gate (opt-in via verify.on_stop in .claude/harness.json).
#
# Before a session is allowed to finish, run the project's verify.steps. If any
# fail, block the stop and hand back the failure so the work continues instead
# of ending on red.
#
# Never blocks when: no config, on_stop false, no runnable steps, or we are
# already in a stop-hook re-loop (never trap a session in a loop it cannot exit).
# ============================================================================
set -uo pipefail

INPUT="$(cat)"
read -r CWD ACTIVE < <(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get("cwd","") or "-", str(d.get("stop_hook_active", False)))
except Exception: print("- False")' 2>/dev/null)

[ "$ACTIVE" = "True" ] && exit 0
[ "$CWD" = "-" ] && exit 0

CFG="$CWD/.claude/harness.json"
[ -f "$CFG" ] || exit 0

ON="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("verify",{}).get("on_stop",False))
except Exception: print(False)' "$CFG" 2>/dev/null)"
[ "$ON" = "True" ] || exit 0

# while-read, not mapfile: macOS ships bash 3.2, where mapfile does not exist and
# this gate would silently never run.
CMDS=()
while IFS= read -r line; do [ -n "$line" ] && CMDS+=("$line"); done < <(python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
cmds=d.get("commands",{}) or {}
for key in (d.get("verify",{}).get("steps") or []):
    c=cmds.get(key)
    if c: print("%s\t%s" % (key,c))
' "$CFG" 2>/dev/null)

[ ${#CMDS[@]} -eq 0 ] && exit 0

FAILED=""; SKIPPED=""
for line in "${CMDS[@]}"; do
  name="${line%%$'\t'*}"; cmd="${line#*$'\t'}"
  out="$(cd "$CWD" && eval "$cmd" 2>&1)"; rc=$?
  [ $rc -eq 0 ] && continue
  # 127 = command not found. The check could not run (dependencies not installed,
  # a fresh cloud workspace) — that is not a failing test, and blocking on it would
  # trap every session in an environment without the project's packages.
  if [ $rc -eq 127 ]; then SKIPPED+="${name} "; continue; fi
  FAILED+="
--- ${name} failed: ${cmd} ---
$(printf '%s' "$out" | tail -40)
"
done

if [ -z "$FAILED" ]; then
  [ -n "$SKIPPED" ] && python3 -c 'import json,sys
print(json.dumps({"systemMessage": "Proof verification could not run " + sys.argv[1].strip() +
  " — the command was not found (dependencies probably not installed here). Not treated as a failure."}))' "$SKIPPED"
  exit 0
fi

python3 -c 'import json,sys
print(json.dumps({"decision":"block","reason":
  "Verification failed before finishing. Fix these, then re-run:\n" + sys.argv[1]}))' "$FAILED"
exit 0
