#!/usr/bin/env bash
# Checks the model tier in every skill's and agent's frontmatter.
#
#   bash tests/frontmatter.test.sh
#
# `claude plugin validate` does not check `model:` values — a typo such as
# `model: haikuu` passes validation and only fails when the skill runs. Every skill
# must declare a tier; agents may, and the builder must say `inherit`, because the
# skill that spawns it passes the model.
# Must run on macOS's stock bash 3.2.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0

frontmatter_model() {
  awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f && /^model:/ {sub(/^model:[ ]*/, ""); print}' "$1"
}

check() {
  file="$1"; required="$2"
  model="$(frontmatter_model "$file")"
  rel="${file#$ROOT/}"
  if [ -z "$model" ]; then
    if [ "$required" = yes ]; then
      fail=$((fail+1)); echo "FAIL  no model:  $rel"
    else
      pass=$((pass+1))
    fi
    return
  fi
  case "$model" in
    opus|sonnet|haiku|inherit) pass=$((pass+1)) ;;
    *) fail=$((fail+1)); echo "FAIL  model: $model  $rel" ;;
  esac
}

for f in "$ROOT"/skills/*/SKILL.md; do check "$f" yes; done
for f in "$ROOT"/agents/*.md; do check "$f" no; done

builder="$ROOT/agents/proof-builder.md"
if [ -f "$builder" ] && [ "$(frontmatter_model "$builder")" != inherit ]; then
  fail=$((fail+1)); echo "FAIL  proof-builder must be model: inherit"
fi

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
