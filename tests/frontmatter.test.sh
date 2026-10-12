#!/usr/bin/env bash
# Checks every skill's and agent's frontmatter.
#
#   bash tests/frontmatter.test.sh
#
# `claude plugin validate` checks neither of the two ways frontmatter silently breaks:
#   - a `model:` typo (`model: haikuu`) passes validation and only fails when the
#     skill runs;
#   - an unquoted description containing ": " is a YAML error, and the skill then
#     loads with empty frontmatter and is never offered.
# This test checks both, pins each skill to its tier (see README, "Models"), and
# requires the builder to say `model: inherit`, because the skill that spawns it
# passes the model.
#
# The fixtures at the bottom prove the checker itself: each one is a small file with
# the result it must produce. Add one whenever the parser is fooled.
# Must run on macOS's stock bash 3.2.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# Prints the frontmatter block (between the opening and closing ---), CR and BOM
# stripped. Exit 1 when there is no opening --- on line 1, 2 when it never closes.
frontmatter() {
  awk '
    { sub(/\r$/, "") }
    NR == 1 { sub(/^\xef\xbb\xbf/, ""); if ($0 != "---") exit 1; open = 1; next }
    open && $0 == "---" { closed = 1; exit }
    open { print }
    END { if (!open) exit 1; if (!closed) exit 2 }
  ' "$1"
}

# The value of one key, with a trailing comment, surrounding space and matching
# quotes removed.
fm_value() {
  printf '%s\n' "$1" | awk -v key="$2" '
    index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      sub(/^[ \t]+/, "", v)
      if (v !~ /^["\047]/) sub(/[ \t]+#.*$/, "", v)
      sub(/[ \t]+$/, "", v)
      if (v ~ /^".*"$/ || v ~ /^\047.*\047$/) v = substr(v, 2, length(v) - 2)
      print v; exit
    }'
}

fm_raw() {
  printf '%s\n' "$1" | awk -v key="$2" 'index($0, key ":") == 1 { v = substr($0, length(key) + 2); sub(/^[ \t]+/, "", v); print v; exit }'
}

expected_tier() {
  case "$1" in
    proof-spec|proof-plan|proof-work|proof-fix) echo opus ;;
    proof-review|proof-design|proof-retro|proof-handoff|proof-learn|proof-init) echo sonnet ;;
    proof-ship) echo haiku ;;
    *) echo "" ;;
  esac
}

# check_file FILE KIND NAME — KIND is skill or agent. Prints "OK" or the reason it fails.
check_file() {
  file="$1"; kind="$2"; name="$3"
  fm="$(frontmatter "$file")"; rc=$?
  [ $rc -eq 1 ] && { echo "no frontmatter"; return; }
  [ $rc -eq 2 ] && { echo "frontmatter never closes"; return; }

  [ -n "$(fm_value "$fm" name)" ] || { echo "no name"; return; }
  desc="$(fm_raw "$fm" description)"
  [ -n "$desc" ] || { echo "no description"; return; }
  case "$desc" in
    \"*|\'*|'|'*|'>'*) ;;
    *': '*) echo "unquoted description contains ': ' (YAML error)"; return ;;
  esac

  model="$(fm_value "$fm" model)"
  if [ "$kind" = skill ]; then
    case "$model" in
      opus|sonnet|haiku) ;;
      '') echo "no model"; return ;;
      *) echo "model: $model is not opus, sonnet or haiku"; return ;;
    esac
    want="$(expected_tier "$name")"
    if [ -n "$want" ] && [ "$model" != "$want" ]; then
      echo "model: $model, expected $want"; return
    fi
    [ -n "$want" ] || { echo "no tier listed for $name in this test"; return; }
  else
    case "$model" in
      ''|opus|sonnet|haiku|inherit) ;;
      *) echo "model: $model is not opus, sonnet, haiku or inherit"; return ;;
    esac
    if [ "$name" = proof-builder ] && [ "$model" != inherit ]; then
      echo "proof-builder must be model: inherit"; return
    fi
  fi
  echo OK
}

expect() {  # expect WANT FILE KIND NAME LABEL — WANT is OK or a substring of the reason
  got="$(check_file "$2" "$3" "$4")"
  case "$got" in
    *"$1"*) pass=$((pass+1)) ;;
    *) fail=$((fail+1)); printf 'FAIL  %s: want "%s", got "%s"\n' "$5" "$1" "$got" ;;
  esac
}

# --- the real files
for f in "$ROOT"/skills/*/SKILL.md; do
  n="$(basename "$(dirname "$f")")"
  expect OK "$f" skill "$n" "${f#$ROOT/}"
done
for f in "$ROOT"/agents/*.md; do
  n="$(basename "$f" .md)"
  expect OK "$f" agent "$n" "${f#$ROOT/}"
done
[ -f "$ROOT/agents/proof-builder.md" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL  agents/proof-builder.md is missing"; }

# --- fixtures: the checker must catch these, and must not trip on these
fx() {  # fx WANT KIND NAME LABEL — file body on stdin
  f="$TMP/fx.md"; cat > "$f"; expect "$1" "$f" "$2" "$3" "fixture: $4"
}
fx OK skill proof-spec "plain" <<'X'
---
name: proof-spec
description: Use when turning an idea into something buildable
model: opus
---
X
printf -- '---\r\nname: proof-spec\r\ndescription: Builds things\r\nmodel: opus\r\n---\r\n' > "$TMP/crlf.md"
expect OK "$TMP/crlf.md" skill proof-spec "fixture: CRLF line endings"
printf '\357\273\277---\nname: proof-spec\ndescription: Builds things\nmodel: opus\n---\n' > "$TMP/bom.md"
expect OK "$TMP/bom.md" skill proof-spec "fixture: byte-order mark"
fx OK skill proof-spec "quoted model" <<'X'
---
name: proof-spec
description: Builds things
model: "opus"
---
X
fx OK skill proof-spec "trailing space and comment" <<'X'
---
name: proof-spec
description: Builds things
model: opus   # tier
---
X
fx OK skill proof-learn "quoted description with ': '" <<'X'
---
name: proof-learn
description: "Owns what the project knows: records a lesson"
model: sonnet
---
X
fx "is not opus" skill proof-ship "typo" <<'X'
---
name: proof-ship
description: Ships things
model: haikuu
---
X
fx "expected opus" skill proof-spec "wrong tier" <<'X'
---
name: proof-spec
description: Builds things
model: haiku
---
X
fx "is not opus" skill proof-spec "inherit on a skill" <<'X'
---
name: proof-spec
description: Builds things
model: inherit
---
X
fx "no model" skill proof-spec "missing model" <<'X'
---
name: proof-spec
description: Builds things
---
X
fx "never closes" skill proof-spec "unterminated, model in the body" <<'X'
---
name: proof-spec
description: Builds things

model: opus
X
fx "YAML error" skill proof-spec "unquoted ': ' in description" <<'X'
---
name: proof-spec
description: Owns what the project knows: records a lesson
model: opus
---
X
fx "no frontmatter" agent proof-review-risk "blank first line" <<'X'

---
name: proof-review-risk
description: Reviews risk
model: sonnet
---
X
printf -- '---\r\nname: proof-x\r\ndescription: Reviews\r\nmodel: bogus\r\n---\r\n' > "$TMP/agent-crlf.md"
expect "is not opus" "$TMP/agent-crlf.md" agent proof-x "fixture: agent, CRLF, bad model"
fx "must be model: inherit" agent proof-builder "builder pinned" <<'X'
---
name: proof-builder
description: Builds the plan
model: sonnet
---
X

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
