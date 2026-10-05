#!/usr/bin/env bash
# ============================================================================
# PreToolUse(Bash) — destructive-command guardrail.
#
# Two levels:
#   deny — catastrophic, never the agent's call: rm -rf on a root, force-push,
#          push to main, wiping a remote database, dropping a whole database.
#   ask  — risky but sometimes legitimate: dropping or emptying a table,
#          pushing migrations, discarding uncommitted work. Shows a permission
#          prompt so a human decides.
# Everything unmatched passes through to the normal permission flow.
#
# Deliberately narrow: a guard that fires on ordinary work gets disabled, and
# then it guards nothing. Two things keep it narrow:
#   - Database rules only fire when a database tool is actually run, so
#     searching code for "DROP TABLE" never trips them.
#   - Commands that only record text (git commit, log, show...) are set aside,
#     so a commit message that *mentions* a dangerous command is not refused.
#     Everything else in a chained command is checked together, so a
#     dangerous part hidden after && or ; is still caught.
#
# Must run on macOS's stock bash 3.2 — no mapfile, no associative arrays.
# Regression cases: tests/pre-bash-guard.test.sh
# ============================================================================
set -uo pipefail

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception: print("")' 2>/dev/null)"
[ -z "$CMD" ] && exit 0

deny() {
  python3 -c 'import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse",
  "permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$1"
  exit 0
}

ask() {
  python3 -c 'import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse",
  "permissionDecision":"ask","permissionDecisionReason":sys.argv[1]}}))' "$1"
  exit 0
}

# Split on && || ; and newlines (not on |, so a pipe into a database tool stays
# with what feeds it), drop the parts that only record text, rejoin the rest.
norm="$(printf '%s' "$CMD" | python3 -c '
import re, sys
keep = []
for part in re.split(r"&&|\|\||;|\n", sys.stdin.read()):
    p = part.strip()
    if not p:
        continue
    if re.match(r"git\s+(commit|log|show|diff|grep|tag|notes|blame)(\s|$)", p):
        continue
    keep.append(p)
print(" ; ".join(keep))' 2>/dev/null)"
[ -z "$norm" ] && exit 0

has() { printf '%s' "$norm" | grep -Eq "$1"; }
hasi() { printf '%s' "$norm" | grep -Eqi "$1"; }

# ---- always refused -----------------------------------------------------------

# rm -rf against a root, home, or the whole tree
if has 'rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)[[:space:]]+(/|~|\$HOME|\.|\*)([[:space:]]|$)'; then
  deny "Refused: 'rm -rf' on a root, home, or the whole tree. Target a specific subpath."
fi

# force-push — rewrites history that may already be pushed
if has 'git[[:space:]]+push.*(--force([^-]|$)|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
  deny "Refused: force-push. Push normally, or ask the user to rewrite history themselves."
fi

# push straight to the base branch — this harness merges via PR
if has 'git[[:space:]]+push[[:space:]].*(origin[[:space:]]+(HEAD:)?(main|master)([[:space:]]|$)|(main|master):(main|master))'; then
  deny "Refused: pushing directly to main. Push the feature branch and open a PR."
fi

# discarding uncommitted work, irreversibly
if has 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f[a-zA-Z]*d|git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*d[a-zA-Z]*f'; then
  deny "Refused: 'git clean -fd' deletes untracked files irreversibly. Scope it to a path or ask first."
fi
if has 'git[[:space:]]+reset[[:space:]]+--hard'; then
  deny "Refused: 'git reset --hard' discards uncommitted work. Stash it, or ask the user."
fi

# writing secrets to disk from the shell
if has '>[[:space:]]*\.?env(\.|[[:space:]]|$)|>[[:space:]]*[^[:space:]]*/\.env'; then
  deny "Refused: writing to a .env file. Ask the user to add secrets themselves."
fi

# ---- databases: only when a database tool is actually run ---------------------
if has '(^|[[:space:];|&(])(psql|pgcli|mysql|sqlite3|supabase|prisma|mongosh|mongo)([[:space:]]|$)'; then

  # refused: wiping a remote database, or dropping a whole database
  if has 'supabase[[:space:]]+db[[:space:]]+reset.*(--linked|--db-url)'; then
    deny "Refused: resetting the linked/remote Supabase database wipes production data. Only the user should ever run this."
  fi
  if hasi 'drop[[:space:]]+database'; then
    deny "Refused: DROP DATABASE destroys an entire database. Only the user should run this."
  fi

  # ask: destructive but sometimes legitimate, usually on a local database
  if hasi 'drop[[:space:]]+(table|schema|view|materialized[[:space:]]+view|function|type)[[:space:]]'; then
    ask "This drops database objects and their data. Confirm it targets a local or disposable database, not production."
  fi
  if hasi '(^|[^a-z_])truncate[[:space:]]'; then
    ask "TRUNCATE empties a table permanently. Confirm it targets a local or disposable database."
  fi
  if hasi 'delete[[:space:]]+from' && ! hasi '[[:space:]]where[[:space:]]'; then
    ask "DELETE with no WHERE clause removes every row. Confirm this is intended."
  fi
  if has 'supabase[[:space:]]+db[[:space:]]+reset'; then
    ask "supabase db reset wipes the local database and re-runs migrations. Confirm nothing local needs keeping."
  fi
  if has 'supabase[[:space:]]+db[[:space:]]+push'; then
    ask "supabase db push applies migrations to the live database. Confirm the migrations were reviewed."
  fi
fi

# ---- ask: discarding uncommitted work -----------------------------------------
if has 'git[[:space:]]+checkout[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)'; then
  ask "'git checkout .' throws away every uncommitted change. Stash first if anything might be needed."
fi
if has 'git[[:space:]]+restore[[:space:]]+(--worktree[[:space:]]+)?(--[[:space:]]+)?\.([[:space:]]|$)'; then
  ask "'git restore .' throws away every uncommitted change. Stash first if anything might be needed."
fi
if has 'git[[:space:]]+branch[[:space:]]+-D[[:space:]]'; then
  ask "'git branch -D' deletes a branch even if its work was never merged. Confirm nothing on it is needed."
fi

exit 0
