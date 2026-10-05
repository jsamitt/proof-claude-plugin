#!/usr/bin/env bash
# ============================================================================
# PreToolUse(Edit|Write|MultiEdit) — protected-path guardrail.
#
# Blocks edits to files that should never be rewritten by an agent: secrets,
# lockfiles, and anything the project lists in protected_paths. Reads the
# project config when present; falls back to a safe built-in list when not,
# so a repo without Proof configured is still protected.
# ============================================================================
set -uo pipefail

INPUT="$(cat)"
read -r FILE CWD < <(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("file_path", "") or "-",
          d.get("cwd", "") or "-")
except Exception:
    print("- -")' 2>/dev/null)
[ "$FILE" = "-" ] && exit 0

deny() {
  python3 -c 'import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse",
  "permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$1"
  exit 0
}

CFG="$CWD/.claude/harness.json"

MATCH="$(python3 - "$FILE" "$CFG" <<'PY' 2>/dev/null
import fnmatch, json, os, sys
path, cfg = sys.argv[1], sys.argv[2]
patterns = ["**/.env", "**/.env.*", "**/*.pem", "**/*.key", "**/*.p12", "**/*.keystore",
            "**/id_rsa", "**/credentials.json",
            "**/package-lock.json", "**/yarn.lock", "**/pnpm-lock.yaml", "**/bun.lockb"]
try:
    extra = json.load(open(cfg)).get("protected_paths") or []
    patterns += [p for p in extra if isinstance(p, str)]
except Exception:
    pass
base = os.path.basename(path)

# Templates carry no secrets and are edited legitimately when config keys change.
if any(base.endswith(sfx) for sfx in (".example", ".sample", ".template", ".dist")):
    raise SystemExit

for pat in patterns:
    tail = pat[3:] if pat.startswith("**/") else pat
    if fnmatch.fnmatch(path, pat) or fnmatch.fnmatch(base, tail) or fnmatch.fnmatch(path, "*/" + tail):
        print(pat); break
PY
)"

if [ -n "$MATCH" ]; then
  deny "Refused: '$FILE' is protected (matches '$MATCH'). Secrets, lockfiles and project-listed paths are edited by the user, not the agent. Change it by hand, or adjust protected_paths in .claude/harness.json."
fi

exit 0
