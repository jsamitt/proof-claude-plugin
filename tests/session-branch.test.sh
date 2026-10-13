#!/usr/bin/env bash
# Regression cases for scripts/hooks/session-branch.sh — the check that stops a
# commit or push when another session (or a manual switch) moved the branch.
#
#   bash tests/session-branch.test.sh
#
# Builds throwaway repos under a temp folder and feeds the hook simulated input.
# The commands are only passed to the hook as text; the test itself moves the
# branches, standing in for "another session".
# Must run on macOS's stock bash 3.2.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/scripts/hooks/session-branch.sh"
GUARD="$ROOT/scripts/hooks/pre-bash-guard.sh"
pass=0; fail=0

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

g() { git -c user.name=t -c user.email=t@example.com -c init.defaultBranch=main "$@" >/dev/null 2>&1; }

input() {  # session cwd command
  python3 -c 'import json,sys; print(json.dumps({"session_id":sys.argv[1],"cwd":sys.argv[2],"tool_input":{"command":sys.argv[3]}}))' "$1" "$2" "$3"
}
record() { input "$1" "$2" "$3" | bash "$HOOK" record; }
check()  { input "$1" "$2" "$3" | bash "$HOOK" check; }
guard()  { input "$1" "$2" "$3" | bash "$GUARD"; }

ok() {  # name, then a command that must succeed
  local name="$1"; shift
  if "$@"; then pass=$((pass+1)); else fail=$((fail+1)); printf 'FAIL  %s\n' "$name"; fi
}
refused() { [ -n "$(check "$1" "$2" "$3")" ]; }
allowed() { [ -z "$(check "$1" "$2" "$3")" ]; }
rec_of() { cat "$(git -C "$1" rev-parse --absolute-git-dir)/proof-sessions/$2" 2>/dev/null; }

# --- setup: repo R (main, a, b, a subfolder, a README), repo O elsewhere
R="$TMP/r"; O="$TMP/o"
g init "$R"; mkdir -p "$R/sub"; echo hi > "$R/README.md"; echo x > "$R/sub/f"
g -C "$R" add -A; g -C "$R" commit -m init; g -C "$R" branch a; g -C "$R" branch b
g init "$O"; g -C "$O" commit --allow-empty -m init

# --- first command records the branch; a match is allowed
record S1 "$R" "ls"
ok "first command records the branch"      [ "$(rec_of "$R" S1)" = main ]
ok "match allowed: commit"                 allowed S1 "$R" 'git commit -m "x"'
ok "match allowed: push"                   allowed S1 "$R" "git push -u origin feat/x"

# --- another session moves the folder to b
g -C "$R" switch b
record S1 "$R" "git status"
record S1 "$R" "git branch"
record S1 "$R" "git log --oneline -3"
ok "git status/branch do not accept the switch" [ "$(rec_of "$R" S1)" = main ]
ok "mismatch refused: commit"              refused S1 "$R" 'git commit -m "x"'
ok "mismatch refused: push"                refused S1 "$R" "git push"
ok "mismatch refused: chained after &&"    refused S1 "$R" 'npm test && git commit -am "x"'
ok "mismatch refused: chained after ;"     refused S1 "$R" "git add . ; git push"
ok "mismatch refused: across a newline"    refused S1 "$R" "$(printf 'git add .\ngit commit -m x')"
ok "mismatch refused: env prefix"          refused S1 "$R" 'GIT_EDITOR=true git commit'
ok "mismatch refused: git -c option"       refused S1 "$R" 'git -c core.hooksPath=/dev/null commit -m x'
msg="$(check S1 "$R" 'git commit -m "x"')"
ok "refusal names the current branch"      grep -q "'b'" <<<"$msg"
ok "refusal names the recorded branch"     grep -q "'main'" <<<"$msg"
ok "refusal says how to accept"            grep -q 'git switch b' <<<"$msg"
ok "refusal says to ask, not switch back"  grep -qi 'ask the user' <<<"$msg"
ok "the bash guard refuses it"             grep -q '"deny"' <<<"$(guard S1 "$R" 'git commit -m "x"')"
ok "the bash guard refuses a chained push" grep -q '"deny"' <<<"$(guard S1 "$R" 'git add -A && git push')"
ok "the bash guard passes other commands"  [ -z "$(guard S1 "$R" 'git status')" ]

# --- mentioning is not running
ok "echo mentioning git push passes"       allowed S1 "$R" 'echo "remember to git push"'
ok "log grep mentioning git commit passes" allowed S1 "$R" 'git log --grep "git commit"'
ok "unquoted heredoc body is not run"      allowed S1 "$R" "$(printf 'cat > notes.txt <<EOF\ngit push\nEOF')"
ok "here-string mentioning git push passes" allowed S1 "$R" "cat <<< 'git push' ; echo ok"
ok "a switch inside a message is not a switch" refused S1 "$R" 'git commit -m "then git switch b"'

# --- a switch earlier in the same command is the session's own
ok "switch -c then commit allowed"         allowed S1 "$R" 'git switch -c c && git commit -m "x"'
ok "checkout -b then commit allowed"       allowed S1 "$R" 'git checkout -b d && git commit -m "x"'
ok "checkout branch then push allowed"     allowed S1 "$R" "git checkout a && git push"
ok "commit before the switch still refused" refused S1 "$R" 'git commit -m x && git switch b'

# --- other folders are not checked; the session's own folder still is
ok "cd elsewhere skipped"                  allowed S1 "$R" "cd $O && git commit -m x"
ok "git -C elsewhere skipped"              allowed S1 "$R" "git -C $O push"
ok "subshell cd elsewhere skipped"         allowed S1 "$R" "(cd $O && git commit -m x)"
ok "back in own folder after subshell"     refused S1 "$R" "(cd $O && make); git commit -m x"
ok "cd into own folder still checked"      refused S1 "$R" "cd $R && git commit -m x"
ok "cd into own subfolder still checked"   refused S1 "$R" "cd sub && git commit -m x"
ok "git -C own folder still checked"       refused S1 "$R" "git -C $R commit -m x"
ok "unresolvable cd skipped"               allowed S1 "$R" 'cd "$WORK" && git commit -m x'

# --- restoring a file is not a switch
record S1 "$R" "git checkout README.md"
record S1 "$R" "git checkout -- sub/f"
record S1 "$R" "git checkout main -- README.md"
ok "file checkout does not accept"         [ "$(rec_of "$R" S1)" = main ]
record S1 "$R" "git -C $O switch -c elsewhere"
ok "a switch in another repo does not accept" [ "$(rec_of "$R" S1)" = main ]

# --- accepting the switch
record S1 "$R" "git switch b"
ok "git switch to the current branch accepts" [ "$(rec_of "$R" S1)" = b ]
ok "commit after accepting goes through"   allowed S1 "$R" 'git commit -m "x"'
g -C "$R" switch a
record S1 "$R" "cd sub && git checkout a"
ok "cd within the repo then checkout records" [ "$(rec_of "$R" S1)" = a ]
g -C "$R" switch b
record S1 "$R/sub" "cd sub && git checkout b"
ok "same, when the hook already sees the cd" [ "$(rec_of "$R" S1)" = b ]
g -C "$R" switch a
record S1 "$R" "git checkout a"

# --- each session has its own record
record S2 "$R" "pwd"
ok "second session records its own branch" [ "$(rec_of "$R" S2)" = a ]
g -C "$R" switch main
record S2 "$R" "git switch main"
ok "S2 switching does not move S1's record" [ "$(rec_of "$R" S1)" = a ]
ok "S1 is refused after S2 switched"       refused S1 "$R" "git push"
ok "S2 is allowed on its own switch"       allowed S2 "$R" "git push"

# --- detached HEAD: nothing recorded or refused
g -C "$R" checkout --detach
record S3 "$R" "ls"
ok "detached: nothing recorded"            [ -z "$(rec_of "$R" S3)" ]
ok "detached: nothing refused"             allowed S1 "$R" "git commit -m x"
g -C "$R" switch main

# --- outside a repo
mkdir -p "$TMP/plain"
record S1 "$TMP/plain" "git switch x"
ok "outside a repo: nothing recorded"      [ ! -d "$TMP/plain/.git" ]
ok "outside a repo: nothing refused"       allowed S1 "$TMP/plain" "git commit -m x"
ok "no session id: nothing refused"        allowed "" "$R" "git commit -m x"

# --- records stay out of the repo, and old ones are cleared
ok "records never show as changes"         [ -z "$(git -C "$R" status --porcelain)" ]
SESS="$(git -C "$R" rev-parse --absolute-git-dir)/proof-sessions"
echo main > "$SESS/OLD"; touch -t 202001010000 "$SESS/OLD"
touch -t 202001010000 "$SESS/S1"
record S1 "$R" "ls"
ok "records untouched for 30 days removed" [ ! -f "$SESS/OLD" ]
ok "a session's own record is kept"        [ -f "$SESS/S1" ]

# --- worktrees keep separate records
W="$TMP/w"; g -C "$R" worktree add -b wt "$W"
record S4 "$W" "ls"
ok "worktree records its own branch"       [ "$(rec_of "$W" S4)" = wt ]
g -C "$R" switch b
ok "moving the main checkout leaves the worktree alone" allowed S4 "$W" "git commit -m x"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
