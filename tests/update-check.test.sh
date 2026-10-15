#!/usr/bin/env bash
# Regression cases for scripts/hooks/update-check.sh — the offer of a newer Proof
# at the start of a new session.
#
#   bash tests/update-check.test.sh
#
# Fake install and marketplace records under a temp folder, and a file:// fixture
# standing in for GitHub, so no network calls. A curl wrapper on PATH counts the
# lookups. Must run on macOS's stock bash 3.2.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/scripts/hooks/update-check.sh"
pass=0; fail=0

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

ok() {  # name, then a command that must succeed
  local name="$1"; shift
  if "$@"; then pass=$((pass+1)); else fail=$((fail+1)); printf 'FAIL  %s\n' "$name"; fi
}

# --- the plugin as installed: a folder with a space in it, holding the hook
PLUGIN="$TMP/claude home/plugins/cache/proof/proof/0.10.0"
mkdir -p "$PLUGIN/scripts/hooks"
ln -s "$HOOK" "$PLUGIN/scripts/hooks/update-check.sh"
INSTALLED="$TMP/installed_plugins.json"
MARKETS="$TMP/known_marketplaces.json"
GH="$TMP/gh"

# --- curl that counts its calls; a slow one for the time limit
mkdir -p "$TMP/bin" "$TMP/slowbin"
REAL_CURL="$(command -v curl)"
printf '#!/bin/sh\necho call >> "%s/curl.log"\nexec "%s" "$@"\n' "$TMP" "$REAL_CURL" > "$TMP/bin/curl"
printf '#!/bin/sh\nexec sleep 20\n' > "$TMP/slowbin/curl"
chmod +x "$TMP/bin/curl" "$TMP/slowbin/curl"
calls() { [ -f "$TMP/curl.log" ] && wc -l < "$TMP/curl.log" | tr -d ' ' || echo 0; }

P="$TMP/proj"; WT="$P/.claude/worktrees/w1"; OUT="$TMP/elsewhere"
mkdir -p "$P/sub" "$WT/src" "$OUT"

installs() {  # scope:version[:projectPath] ...  (installed at $PLUGIN unless the version differs)
  python3 -I - "$INSTALLED" "$PLUGIN" "$@" <<'EOF'
import json, os, sys
out, plugin, specs = sys.argv[1], sys.argv[2], sys.argv[3:]
entries = []
for s in specs:
    scope, version, *rest = s.split(":", 2)
    e = {"scope": scope, "version": version,
         "installPath": plugin if version == "0.10.0" else os.path.join(os.path.dirname(plugin), version)}
    if rest:
        e["projectPath"] = rest[0]
    entries.append(e)
json.dump({"version": 2, "plugins": {"proof@proof": entries,
           "other@elsewhere": [{"scope": "user", "version": "9.9.9", "installPath": "/nowhere"}]}},
          open(out, "w"))
EOF
}
market() {  # source repo
  python3 -I -c 'import json,sys; json.dump({"proof":{"source":{"source":sys.argv[2],"repo":sys.argv[3]}},
"other":{"source":{"source":"github","repo":"x/y"}}}, open(sys.argv[1],"w"))' "$MARKETS" "$1" "$2"
}
release() {  # repo version — what that repo's default branch says
  mkdir -p "$GH/$1"; printf '{"name":"proof","version":"%s"}\n' "$2" > "$GH/$1/plugin.json"
}

DATA="$TMP/data/0"; n=0
fresh() { n=$((n+1)); DATA="$TMP/data/$n"; }   # a new machine-day: no cache, nothing skipped

run() {  # source cwd [path prefix] — the hook's output
  python3 -I -c 'import json,sys; print(json.dumps({"session_id":"s","hook_event_name":"SessionStart","source":sys.argv[1],"cwd":sys.argv[2]}))' "$1" "$2" |
    PATH="${3:-$TMP/bin}:$PATH" CLAUDE_PLUGIN_ROOT="${ROOT_OVERRIDE:-$PLUGIN}" CLAUDE_PLUGIN_DATA="$DATA" \
    PROOF_INSTALLED_PLUGINS="$INSTALLED" PROOF_KNOWN_MARKETPLACES="$MARKETS" \
    PROOF_LATEST_URL="file://$GH/{repo}/plugin.json" bash "$HOOK"
}
context() {  # the additionalContext the hook gave, or nothing
  python3 -I -c 'import json,sys
t=sys.stdin.read().strip()
if t:
    d=json.loads(t)["hookSpecificOutput"]
    assert d["hookEventName"]=="SessionStart"
    print(d["additionalContext"])'
}
offer() { run "$@" | context; }
nothing() { [ -z "$(run "$@")" ]; }
has() { grep -qF -- "$2" <<<"$1"; }
skip_cmd() { sed -n 's/^- If they say not now, run: //p' <<<"$1"; }
update_cmd() { sed -n 's/^- If they say yes, run: //p' <<<"$1"; }

# --- behind: the offer, naming both versions, with the user install's command
market github jsamitt/proof-claude-plugin
release jsamitt/proof-claude-plugin 0.11.0
installs user:0.10.0
fresh; o="$(offer startup "$OUT")"
ok "behind gets the offer"                    [ -n "$o" ]
ok "the offer names the latest version"       has "$o" "Proof 0.11.0 is available"
ok "the offer names this install's version"   has "$o" "(this project has 0.10.0)"
ok "the offer asks whether to update"         has "$o" "Update now?"
ok "the offer says to restart after"          has "$o" "restart Claude Code"
ok "user install: plain update command"       [ "$(update_cmd "$o")" = "claude plugin update proof@proof" ]
ok "the hook exits 0"                         bash -c "true | '$HOOK'"

# --- up to date, or the release is older: nothing
release jsamitt/proof-claude-plugin 0.10.0
fresh; ok "up to date gets nothing"           nothing startup "$OUT"
release jsamitt/proof-claude-plugin 0.9.0
fresh; ok "0.9.0 is older than 0.10.0"        nothing startup "$OUT"
installs user:0.9.0
release jsamitt/proof-claude-plugin 0.10.0
fresh; ok "0.10.0 is newer than 0.9.0"        has "$(offer startup "$OUT")" "Proof 0.10.0 is available"
installs user:0.10.0

# --- the repo comes from the marketplace record; non-GitHub sources are not looked up
market github someone/fork
release someone/fork 0.12.0
fresh; ok "the marketplace's repo is the one read" has "$(offer startup "$OUT")" "Proof 0.12.0 is available"
market directory /some/local/checkout
fresh; ok "non-GitHub marketplace: nothing"   nothing startup "$OUT"
market github jsamitt/proof-claude-plugin
release jsamitt/proof-claude-plugin 0.11.0

# --- failed lookups: nothing
rm -f "$GH/jsamitt/proof-claude-plugin/plugin.json"
fresh; ok "lookup fails: nothing"             nothing startup "$OUT"
echo '{"version": ' > "$GH/jsamitt/proof-claude-plugin/plugin.json"
fresh; ok "malformed plugin.json: nothing"    nothing startup "$OUT"
echo '{"version": "latest"}' > "$GH/jsamitt/proof-claude-plugin/plugin.json"
fresh; ok "non-numeric version: nothing"      nothing startup "$OUT"
release jsamitt/proof-claude-plugin 0.11.0
fresh; start=$SECONDS
ok "lookup over 3 seconds: nothing"           nothing startup "$OUT" "$TMP/slowbin"
ok "and gives up within 5 seconds"            [ $((SECONDS - start)) -le 5 ]

# --- once a day: the saved answer is used, with no second lookup
fresh; rm -f "$TMP/curl.log"
offer startup "$OUT" >/dev/null
ok "first check of the day looks it up"       [ "$(calls)" = 1 ]
o="$(offer startup "$P")"
ok "same day: no second lookup"               [ "$(calls)" = 1 ]
ok "same day: the saved answer still offers"  has "$o" "Proof 0.11.0 is available"
release jsamitt/proof-claude-plugin 0.12.0
ok "same day: a release since is not seen yet" has "$(offer startup "$OUT")" "Proof 0.11.0 is available"
python3 -I -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["date"]="2000-01-01"; json.dump(d,open(p,"w"))' "$DATA/update-check.json"
ok "next day: looks it up again"              has "$(offer startup "$OUT")" "Proof 0.12.0 is available"
ok "next day: one more lookup"                [ "$(calls)" = 2 ]
rm -f "$GH/jsamitt/proof-claude-plugin/plugin.json"
fresh; rm -f "$TMP/curl.log"
run startup "$OUT" >/dev/null; run startup "$OUT" >/dev/null
ok "a failed lookup also counts for the day"  [ "$(calls)" = 1 ]
release jsamitt/proof-claude-plugin 0.11.0

# --- not now: that version is never offered again for that install; a newer one is
fresh; o="$(offer startup "$OUT")"
s="$(skip_cmd "$o")"
ok "the offer carries a skip command"         [ -n "$s" ]
ok "the skip command runs"                    bash -c "$s" >/dev/null
ok "skipped version: nothing"                 nothing startup "$OUT"
rm -f "$DATA/update-check.json"
ok "skipped version: nothing on another day"  nothing startup "$OUT"
release jsamitt/proof-claude-plugin 0.12.0
rm -f "$DATA/update-check.json"
ok "a newer version is offered"               has "$(offer startup "$OUT")" "Proof 0.12.0 is available"
ok "a bad skip is refused"                    bash -c "! bash '$HOOK' skip relative user 0.12.0 >/dev/null 2>&1"
ok "a bad skip version is refused"            bash -c "! bash '$HOOK' skip '$DATA' user 'x; rm' >/dev/null 2>&1"

# --- project and worktree installs: their own version, their own command
release jsamitt/proof-claude-plugin 0.11.0
installs user:0.11.0 "project:0.10.0:$P" "project:0.8.1:$WT"
fresh
ok "user install up to date: nothing outside the project" nothing startup "$OUT"
o="$(offer startup "$P/sub")"
ok "project install: offered from a subfolder" has "$o" "(this project has 0.10.0)"
ok "project install: its own command"         [ "$(update_cmd "$o")" = "cd '$P' && claude plugin update proof@proof --scope project" ]
o="$(offer startup "$WT/src")"
ok "worktree install: its own version"        has "$o" "(this project has 0.8.1)"
ok "worktree install: its own command"        [ "$(update_cmd "$o")" = "cd '$WT' && claude plugin update proof@proof --scope project" ]
bash -c "$(skip_cmd "$o")" >/dev/null
ok "worktree skipped: nothing there"          nothing startup "$WT"
ok "worktree skipped: the project still offered" has "$(offer startup "$P")" "(this project has 0.10.0)"
installs user:0.10.0 "project:0.11.0:$P"
fresh
ok "project up to date: nothing, though the user install is behind" nothing startup "$P/sub"
ok "the user install still offered elsewhere" has "$(offer startup "$OUT")" "(this project has 0.10.0)"
installs user:0.10.0 "local:0.10.0:$P"
fresh
ok "local install: --scope local"             [ "$(update_cmd "$(offer startup "$P")")" = "cd '$P' && claude plugin update proof@proof --scope local" ]

# --- only a new session
installs user:0.10.0
for src in resume clear compact fork ""; do
  fresh; ok "source '$src': nothing"          nothing "$src" "$OUT"
done

# --- no install found, or records unreadable: nothing
installs "project:0.10.0:$P"
fresh; ok "no install for this folder: nothing" nothing startup "$OUT"
installs user:0.10.0
ROOT_OVERRIDE="$TMP/dev checkout"; mkdir -p "$ROOT_OVERRIDE"
fresh; ok "plugin not from the install record: nothing" nothing startup "$OUT"
ROOT_OVERRIDE="$TMP/claude home/plugins/cache/proof/proof/0.11.0"; mkdir -p "$ROOT_OVERRIDE"
fresh; ok "key read from the cache path when the folder isn't recorded" has "$(offer startup "$OUT")" "Proof 0.11.0 is available"
unset ROOT_OVERRIDE
echo '{"plugins": ' > "$INSTALLED"
fresh; ok "malformed install record: nothing" nothing startup "$OUT"
installs user:0.10.0
echo 'nope' > "$MARKETS"
fresh; ok "malformed marketplace record: nothing" nothing startup "$OUT"
market github jsamitt/proof-claude-plugin
fresh; ok "malformed hook input: nothing"     bash -c "echo '{' | CLAUDE_PLUGIN_ROOT='$PLUGIN' CLAUDE_PLUGIN_DATA='$DATA' bash '$HOOK' | grep -q . && exit 1 || exit 0"

# --- review round 1: the project folder can't run code; hostile or odd records stay safe
installs user:0.10.0; market github jsamitt/proof-claude-plugin; release jsamitt/proof-claude-plugin 0.11.0
EVIL="$TMP/evil repo"; mkdir -p "$EVIL"
for mod in json re time signal subprocess; do
  printf 'open(%s, "w").write("ran")\n' "'$TMP/RAN_$mod'" > "$EVIL/$mod.py"
done
fresh; o="$(cd "$EVIL" && offer startup "$EVIL")"
ok "a json.py (etc.) in the folder is not run"  [ -z "$(ls "$TMP" | grep '^RAN_')" ]
ok "and the offer still works there"            has "$o" "Proof 0.11.0 is available"
(cd "$EVIL" && bash -c "$(skip_cmd "$o")" >/dev/null)
ok "skip from that folder doesn't run it either" [ -z "$(ls "$TMP" | grep '^RAN_')" ]

python3 -I - "$INSTALLED" "$PLUGIN" <<'PYK'
import json, sys
json.dump({"version": 2, "plugins": {"proof;touch PWNED;x@proof": [
    {"scope": "user", "version": "0.10.0", "installPath": sys.argv[2]}]}}, open(sys.argv[1], "w"))
PYK
fresh; ok "a plugin key with shell characters: nothing" nothing startup "$OUT"
installs user:0.10.0

printf '{"version": "0.11.0\\n"}' > "$GH/jsamitt/proof-claude-plugin/plugin.json"
fresh; o="$(offer startup "$OUT")"
ok "a version with a stray newline is shown clean" has "$o" "Proof 0.11.0 is available (this"
ok "and its skip command is clean"              [ "$(skip_cmd "$o" | grep -c .)" = 1 ]
bash -c "$(skip_cmd "$o")" >/dev/null
ok "and skipping it holds"                      nothing startup "$OUT"
printf '{"version": "\xd9\xa0.\xd9\xa1\xd9\xa1.\xd9\xa0"}' > "$GH/jsamitt/proof-claude-plugin/plugin.json"
fresh; ok "non-ASCII digits: nothing"           nothing startup "$OUT"
python3 -I -c 'import json,sys; json.dump({"version":"0.11.0","pad":"x"*100000}, open(sys.argv[1],"w"))' "$GH/jsamitt/proof-claude-plugin/plugin.json"
fresh; ok "a plugin.json over 64 KB: nothing"   nothing startup "$OUT"
release jsamitt/proof-claude-plugin 0.11.0

fresh; mkdir -p "$(dirname "$DATA")"; : > "$DATA"; rm -f "$TMP/curl.log"
run startup "$OUT" >/dev/null; run startup "$OUT" >/dev/null
ok "data folder can't be written: no lookups at all" [ "$(calls)" = 0 ]

FIFO="$TMP/records.fifo"; mkfifo "$FIFO"
SAVED="$INSTALLED"; INSTALLED="$FIFO"
fresh; start=$SECONDS
ok "a record that never answers: nothing"       nothing startup "$OUT"
ok "and the check gives up within 6 seconds"    [ $((SECONDS - start)) -le 6 ]
INSTALLED="$SAVED"

# --- the data stays out of the repo
g() { git -c user.name=t -c user.email=t@example.com -c init.defaultBranch=main "$@" >/dev/null 2>&1; }
g init "$P"; g -C "$P" commit --allow-empty -m init
fresh; offer startup "$P" >/dev/null; bash -c "$(skip_cmd "$(offer startup "$OUT")")" >/dev/null
ok "the data is written to the data folder"   [ -f "$DATA/update-check.json" ] && [ -f "$DATA/skipped.json" ]
ok "nothing written to the project"           [ -z "$(git -C "$P" status --porcelain)" ]

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
