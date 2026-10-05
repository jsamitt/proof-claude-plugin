#!/usr/bin/env bash
# Regression cases for scripts/hooks/pre-bash-guard.sh.
#
#   bash tests/pre-bash-guard.test.sh
#
# Each case is: expected result (DENY / ASK / PASS), a tab, then the command.
# The commands are only passed to the guard as text — nothing here runs them.
# Add a case whenever the guard gets a new rule or a new false alarm is found.
# Must run on macOS's stock bash 3.2.

GUARD="$(cd "$(dirname "$0")/.." && pwd)/scripts/hooks/pre-bash-guard.sh"
pass=0; fail=0

while IFS=$'\t' read -r want cmd; do
  case "$want" in ''|\#*) continue ;; esac
  out="$(python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$cmd" | bash "$GUARD")"
  got=PASS
  case "$out" in *'"deny"'*) got=DENY ;; *'"ask"'*) got=ASK ;; esac
  if [ "$got" = "$want" ]; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); printf 'FAIL  want=%-4s got=%-4s  %s\n' "$want" "$got" "$cmd"
  fi
done <<'CASES'
# --- always refused
DENY	rm -rf /
DENY	rm -rf ~
DENY	git push --force origin feat/x
DENY	git push origin main
DENY	git reset --hard HEAD~2
DENY	git clean -fd
DENY	echo KEY=1 > web/.env
DENY	npx supabase db reset --linked
DENY	supabase db reset --db-url postgres://prod
DENY	psql "$DATABASE_URL" -c "DROP DATABASE app"
# --- hidden in a chain: still refused
DENY	git commit -m "wip" && git push origin main
DENY	cd web && npx supabase db reset --linked
DENY	git log --oneline -1; supabase db reset --linked
# --- ask: risky but sometimes legitimate
ASK	psql -c "DROP TABLE player_progress"
ASK	psql -c "drop table if exists words"
ASK	psql -c "SELECT 1; DROP TABLE words"
ASK	echo "DROP TABLE words" | psql
ASK	psql $DB -c "TRUNCATE completed_levels"
ASK	psql -c "DELETE FROM level_play_history"
ASK	supabase db reset
ASK	npx supabase db push
ASK	git checkout .
ASK	git checkout -- .
ASK	git restore .
ASK	git branch -D feat/old
# --- must pass: everyday work
PASS	cd mobile && npm test
PASS	git push -u origin feat/14-hints
PASS	git checkout main
PASS	git checkout -b feat/14-hints
PASS	git checkout src/app/home.jsx
PASS	git restore --staged .
PASS	git branch -d merged-branch
PASS	rm -rf web/build
PASS	cd web && railway up
PASS	cd mobile && eas build --platform ios
PASS	supabase migration new add_hints
PASS	supabase db diff
PASS	psql -c "SELECT * FROM words LIMIT 5"
PASS	psql -c "DELETE FROM sessions WHERE expires_at < now()"
# --- must pass: mentioning a dangerous command is not running one
PASS	grep -rn "DROP TABLE" supabase/migrations/
PASS	rg -i "truncate" web/src
PASS	echo "truncate the title" | wc -c
PASS	git commit -m "guard: refuse supabase db reset --linked"
PASS	git commit -m "block git push origin main and DROP DATABASE"
PASS	git log --grep "git reset --hard"
CASES

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
