#!/usr/bin/env bash
# ============================================================================
# setup-board.sh — create and configure the GitHub project board for this repo.
#
# Reads .claude/harness.json. Idempotent: safe to re-run on a repo that
# already has some or all of this. Creates nothing that already exists.
#
#   scripts/setup-board.sh                          # create / reconcile
#   scripts/setup-board.sh --dry-run                # show what it would do
#   scripts/setup-board.sh --remove-done-workflows  # also delete the built-in
#       "Item closed" and "Pull request merged" workflows (PERMANENT: GitHub's
#       API cannot recreate them). Only pass this after the user has agreed.
#   scripts/setup-board.sh --enable-repo-features   # turn on the repository
#       features Proof uses (Issues, Discussions) if they are off. A visible
#       repo setting change: only pass this after the user has agreed.
#
# Done automatically: board, repo link, Status stage options, labels, adding
# existing open issues. Reported for the user (GitHub's API cannot do them):
# the auto-add workflow, the default repository, and a missing Ideas
# discussion category. Repo features that are off are reported, and turned on
# only with --enable-repo-features. Output lines starting
# "ACTION NEEDED" / "CHECK" / "DECIDE" are what proof-init relays.
#
# Portable to macOS's stock bash 3.2: no mapfile, no associative arrays, and
# ${arr[@]+"${arr[@]}"} for arrays that may be empty under set -u.
# ============================================================================
set -uo pipefail

DRY=0; REMOVE_DONE=0; ENABLE_FEATURES=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --remove-done-workflows) REMOVE_DONE=1 ;;
    --enable-repo-features) ENABLE_FEATURES=1 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done
CFG="${PROOF_CFG:-.claude/harness.json}"
[ -f "$CFG" ] || { echo "No $CFG — run /proof-init first." >&2; exit 1; }

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY" = 1 ]; then say "  would run: $*"; else "$@"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

OWNER="$(gh repo view --json owner -q '.owner.login')" || exit 1
REPO="$(gh repo view --json name -q '.name')"

# Field first, then the rest of the line: a board name may contain spaces.
read -r FIELD BOARD_NAME <<<"$(python3 -c '
import json,sys
d=json.load(open(sys.argv[1])).get("board",{})
print(d.get("field") or "Status", d.get("name","") or "")
' "$CFG")"

LABELS=()
while IFS= read -r line; do [ -n "$line" ] && LABELS+=("$line"); done < <(python3 -c '
import json,sys
lb=json.load(open(sys.argv[1])).get("labels",{})
lb.setdefault("needs_design", "needs-design")   # added in 0.7.0; older configs lack it
for v in lb.values():
    if v: print(v)
' "$CFG")

if [ "$(gh api "users/$OWNER" -q .type 2>/dev/null)" = "Organization" ]; then
  OWNER_KIND=organization; URL_KIND=orgs
else
  OWNER_KIND=user; URL_KIND=users
fi
ACTIONS=0

# --- 0. Repository features ---------------------------------------------------
# Proof files work as issues, and parks worked-out ideas as Discussions in the
# "Ideas" category (/proof-spec, /proof-plan, the overlap check). Both can be
# switched off per repository. gh can turn them on; nothing in GitHub's API can
# create a discussion category, so a missing Ideas category is reported.
say "Repository: $OWNER/$REPO"
read -r HAS_ISSUES HAS_DISCUSSIONS <<<"$(gh api "repos/$OWNER/$REPO" -q '"\(.has_issues) \(.has_discussions)"' 2>/dev/null)"
OFF=()
[ "$HAS_ISSUES" = "true" ] || OFF+=("Issues")
[ "$HAS_DISCUSSIONS" = "true" ] || OFF+=("Discussions")
if [ ${#OFF[@]} -eq 0 ]; then
  say "  issues and discussions on"
elif [ "$ENABLE_FEATURES" = 1 ]; then
  for f in "${OFF[@]}"; do
    [ "$DRY" = 1 ] && { say "  would turn on: $f"; continue; }
    case "$f" in
      Issues) run gh repo edit "$OWNER/$REPO" --enable-issues >/dev/null 2>&1 && say "  turned on: Issues" || say "  could not turn on Issues" ;;
      Discussions) run gh repo edit "$OWNER/$REPO" --enable-discussions >/dev/null 2>&1 && say "  turned on: Discussions" || say "  could not turn on Discussions" ;;
    esac
  done
  [ "$DRY" = 0 ] && HAS_DISCUSSIONS="$(gh api "repos/$OWNER/$REPO" -q .has_discussions 2>/dev/null)"
else
  say "  DECIDE (repo-features) — switched off on this repository: ${OFF[*]}"
  say "    Turn on: re-run with --enable-repo-features, or https://github.com/$OWNER/$REPO/settings → Features"
fi
if [ "$HAS_DISCUSSIONS" = "true" ] && [ "$DRY" = 0 ]; then
  if gh api graphql -f query='query($o:String!,$r:String!){repository(owner:$o,name:$r){discussionCategories(first:50){nodes{name}}}}' \
       -f o="$OWNER" -f r="$REPO" -q '.data.repository.discussionCategories.nodes[].name' 2>/dev/null | grep -qxF "Ideas"; then
    say "  Ideas discussion category present"
  else
    say "  ACTION NEEDED (ideas-category) — Discussions has no \"Ideas\" category; /proof-spec parks ideas there."
    say "    https://github.com/$OWNER/$REPO/discussions/categories/new → Name: Ideas, Format: Open-ended discussion"
    ACTIONS=1
  fi
fi

# --- 1. Project board -------------------------------------------------------
say "Board: '$BOARD_NAME' (owner: $OWNER)"
NUM="$(gh project list --owner "$OWNER" --format json 2>/dev/null | python3 -c '
import json,sys
hits=[p for p in json.load(sys.stdin).get("projects",[]) if p.get("title")==sys.argv[1]]
print(hits[0]["number"] if len(hits)==1 else "")
' "$BOARD_NAME")"

if [ -z "$NUM" ]; then
  say "  creating project"
  if [ "$DRY" = 0 ]; then
    NUM="$(gh project create --owner "$OWNER" --title "$BOARD_NAME" --format json -q '.number')" \
      || { echo "  Could not create the project. Your GitHub token likely lacks the 'project' scope:" >&2
           echo "    gh auth refresh -s project,read:project" >&2
           echo "  Set board.enabled=false in $CFG to run on labels alone." >&2; exit 1; }
  fi
else
  say "  exists (#$NUM)"
fi
BOARD_URL="https://github.com/$URL_KIND/$OWNER/projects/${NUM:-?}"

if [ -n "${NUM:-}" ]; then
  PROJECT_ID="$(gh project view "$NUM" --owner "$OWNER" --format json -q .id 2>/dev/null)"
fi

# --- 2. Link the repo -------------------------------------------------------
# Every run, not only at creation: a board made by hand may never have been linked.
if [ -n "${PROJECT_ID:-}" ]; then
  if gh api graphql -f query='query($id:ID!){node(id:$id){... on ProjectV2{repositories(first:100){nodes{nameWithOwner}}}}}' \
       -f id="$PROJECT_ID" -q '.data.node.repositories.nodes[].nameWithOwner' 2>/dev/null \
       | grep -qixF "$OWNER/$REPO"; then
    say "  linked to $OWNER/$REPO"
  else
    say "  linking to $OWNER/$REPO"
    run gh project link "$NUM" --owner "$OWNER" --repo "$OWNER/$REPO" >/dev/null 2>&1 \
      || say "  could not link the repo; link it under $BOARD_URL/settings → Manage access"
  fi
fi

# --- 3. Status stage options ------------------------------------------------
# Set through updateProjectV2Field. Existing option IDs are always sent back,
# otherwise GitHub recreates the options and every card loses its status.
# A new board's Todo / In Progress / Done are renamed in place (same IDs) to
# the backlog / in_dev / shipped stages, so cards and built-in workflows that
# point at them keep working.
if [ -n "${PROJECT_ID:-}" ]; then
  gh api graphql -f query='query($id:ID!){node(id:$id){... on ProjectV2{fields(first:50){nodes{... on ProjectV2SingleSelectField{id name options{id name color description}}}}}}}' \
    -f id="$PROJECT_ID" > "$TMP/fields.json" 2>/dev/null
  PLAN="$(python3 - "$CFG" "$FIELD" "$TMP/fields.json" "$TMP/req.json" <<'PY'
import json, sys
cfg, field_name, fields_path, req_path = sys.argv[1:5]
stages = json.load(open(cfg)).get("board", {}).get("stages", {}) or {}
order = ["backlog", "spec_draft", "ready", "in_dev", "in_review", "shipped"]
want = [(k, stages[k]) for k in order if stages.get(k)] + \
       [(k, v) for k, v in stages.items() if k not in order and v]
nodes = json.load(open(fields_path))["data"]["node"]["fields"]["nodes"]
field = next((f for f in nodes if f and f.get("name") == field_name), None)
if not field:
    print("NOFIELD"); sys.exit(0)
cur = field["options"]
by_name = {o["name"]: o for o in cur}
defaults = {"backlog": "Todo", "in_dev": "In Progress", "shipped": "Done"}
wanted_names = {v for _, v in want}
used, out, renames = set(), [], []
for key, name in want:
    o = by_name.get(name)
    if not o:
        d = by_name.get(defaults.get(key, ""))
        if d and d["name"] not in wanted_names and d["id"] not in used:
            o = d; renames.append("%s → %s" % (d["name"], name))
    if o:
        used.add(o["id"])
        out.append({"id": o["id"], "name": name, "color": o["color"], "description": o.get("description") or ""})
    else:
        out.append({"name": name, "color": "GRAY", "description": ""})
# Keep any other existing options (harmless, and removing one would clear cards).
for o in cur:
    if o["id"] not in used:
        out.append({"id": o["id"], "name": o["name"], "color": o["color"], "description": o.get("description") or ""})
if [o["name"] for o in out] == [o["name"] for o in cur]:
    print("OK"); sys.exit(0)
q = ('mutation($f:ID!,$o:[ProjectV2SingleSelectFieldOptionInput!]){updateProjectV2Field('
     'input:{fieldId:$f,singleSelectOptions:$o}){projectV2Field{... on ProjectV2SingleSelectField{options{name}}}}}')
json.dump({"query": q, "variables": {"f": field["id"], "o": out}}, open(req_path, "w"))
print("SET " + "; ".join(renames + ["add " + o["name"] for o in out if "id" not in o]))
PY
)"
  case "$PLAN" in
    OK) say "  all stage options present" ;;
    NOFIELD) say "  ACTION NEEDED — the board has no single-select field named '$FIELD'."; ACTIONS=1 ;;
    SET*)
      say "  stage options: ${PLAN#SET }"
      if [ "$DRY" = 0 ]; then
        gh api graphql --input "$TMP/req.json" >/dev/null 2>&1 \
          && say "  stage options set" \
          || { say "  ACTION NEEDED — could not set the '$FIELD' options. Add them at $BOARD_URL/settings"; ACTIONS=1; }
      fi ;;
  esac
fi

# --- 4. Workflows -----------------------------------------------------------
if [ -n "${PROJECT_ID:-}" ]; then
  gh api graphql -f query='query($id:ID!){node(id:$id){... on ProjectV2{workflows(first:50){nodes{id name enabled updatedAt}}}}}' \
    -f id="$PROJECT_ID" -q '.data.node.workflows.nodes[] | "\(.id)\t\(.name)\t\(.enabled)\t\(.updatedAt)"' > "$TMP/wf.tsv" 2>/dev/null

  # 4a. Auto-add. Proof puts an issue on the board only when one of its skills
  # touches it; issues opened anywhere else need this. The API can read whether
  # it is enabled, but not its filter, and cannot create or enable it. GitHub
  # pre-fills the filter with label:bug, which silently skips every other issue,
  # so "enabled" proves little: check behaviour instead. Any open issue created
  # after the workflow was last saved that is missing from the board means the
  # filter is excluding it. Runs before step 6 adds missing issues.
  AUTOADD_LINE="$(awk -F'\t' '$2=="Auto-add to project" && $3=="true"' "$TMP/wf.tsv" | head -1)"
  if [ -n "$AUTOADD_LINE" ]; then
    AUTOADD_SINCE="$(printf '%s' "$AUTOADD_LINE" | cut -f4 | cut -c1-10)"
    gh project item-list "$NUM" --owner "$OWNER" --limit 1000 --format json \
      -q '.items[].content.url' > "$TMP/on-board-now.txt" 2>/dev/null
    SKIPPED="$(gh issue list --state open --limit 200 --search "created:>$AUTOADD_SINCE" \
      --json url,title -q '.[] | "\(.url)\t\(.title)"' 2>/dev/null \
      | while IFS=$'\t' read -r u t; do
          [ -n "$u" ] && [ "$t" != "Proof digest" ] && ! grep -qxF "$u" "$TMP/on-board-now.txt" && printf '%s\n' "$t"
        done)"
    if [ -n "$SKIPPED" ]; then
      say "  ACTION NEEDED (auto-add-filter) — auto-add is on, but it skipped issues opened since it was set up:"
      printf '%s\n' "$SKIPPED" | head -5 | while IFS= read -r t; do say "    • $t"; done
      say "    Its filter is probably GitHub's pre-filled one (\"... label:bug\"). Change it at"
      say "    $BOARD_URL/workflows → 'Auto-add to project' → Edit → Filter: is:issue is:open"
      ACTIONS=1
    else
      say "  auto-add workflow enabled. Its filter can't be read: confirm it is exactly \"is:issue is:open\""
      say "    (GitHub pre-fills \"label:bug\", which skips everything else)"
    fi
  else
    say "  ACTION NEEDED (auto-add) — new issues will not reach the board on their own."
    say "    $BOARD_URL/workflows → 'Auto-add to project' → Edit"
    say "    Repository: $REPO   Filter: replace GitHub's pre-filled one with exactly: is:issue is:open   → Save and turn on"
    ACTIONS=1
  fi

  # 4b. Built-ins that move cards to the old "Done" option (now the shipped
  # stage) when a PR merges or an issue closes, i.e. before /proof-ship has
  # released anything. Deleting is permanent, so only on explicit request.
  DONE_WF="$(awk -F'\t' '($2=="Item closed" || $2=="Pull request merged") && $3=="true"' "$TMP/wf.tsv")"
  if [ -n "$DONE_WF" ]; then
    if [ "$REMOVE_DONE" = 1 ]; then
      while IFS=$'\t' read -r wid wname _; do
        run gh api graphql -f query='mutation($w:ID!){deleteProjectV2Workflow(input:{workflowId:$w}){deletedWorkflowId}}' \
          -f w="$wid" >/dev/null 2>&1 && say "  removed workflow: $wname" || say "  could not remove workflow: $wname"
      done <<<"$DONE_WF"
    else
      say "  DECIDE (done-workflows) — these move cards to the shipped stage before anything ships:"
      while IFS=$'\t' read -r _ wname _; do say "    • $wname"; done <<<"$DONE_WF"
      say "    Remove: re-run with --remove-done-workflows (permanent), or turn them off at $BOARD_URL/workflows"
    fi
  fi
fi

# --- 5. Default repository --------------------------------------------------
# Where "+ Add item" on the board creates issues. Not in GitHub's API at all,
# so it can be neither set nor checked.
if [ "$DRY" = 0 ] && [ -n "${NUM:-}" ]; then
  say "  CHECK (default-repo) — set the board's default repository to $OWNER/$REPO:"
  say "    $BOARD_URL/settings → Default repository"
fi

# --- 6. Existing open issues ------------------------------------------------
# Auto-add only catches issues created or updated after it is turned on, so
# add the backlog once. The digest issue is a log, not work, and stays off.
if [ -n "${NUM:-}" ]; then
  gh project item-list "$NUM" --owner "$OWNER" --limit 1000 --format json \
    -q '.items[].content.url' > "$TMP/on-board.txt" 2>/dev/null
  ADDED=0
  while IFS=$'\t' read -r url title; do
    [ -n "$url" ] || continue
    [ "$title" = "Proof digest" ] && continue
    grep -qxF "$url" "$TMP/on-board.txt" && continue
    run gh project item-add "$NUM" --owner "$OWNER" --url "$url" >/dev/null 2>&1 \
      && { say "  added: $title"; ADDED=$((ADDED+1)); }
  done < <(gh issue list --state open --limit 500 --json url,title -q '.[] | "\(.url)\t\(.title)"' 2>/dev/null)
  [ "$ADDED" = 0 ] && say "  all open issues on the board"
fi

# --- 7. Labels --------------------------------------------------------------
say "Labels:"
color_for() {
  case "$1" in
    ready-to-dev) echo 0E8A16 ;; in-progress) echo FBCA04 ;; discovered) echo C5DEF5 ;;
    blocked) echo B60205 ;; P1) echo D73A4A ;; P2) echo F9A03F ;; P3) echo BFD4F2 ;;
    needs-investigation) echo 8250DF ;; needs-design) echo D4C5F9 ;; *) echo EDEDED ;;
  esac
}
EXISTING_LABELS="$(gh label list --limit 200 --json name -q '.[].name' 2>/dev/null)"
for l in ${LABELS[@]+"${LABELS[@]}"} bug feature chore; do
  if grep -qxF "$l" <<<"$EXISTING_LABELS"; then
    say "  exists: $l"
  else
    say "  creating: $l"
    run gh label create "$l" --color "$(color_for "$l")" --force >/dev/null 2>&1 || true
  fi
done

say ""
say "Done. Board: $BOARD_URL"
[ "$ACTIONS" = 1 ] && say "Some steps need doing by hand (ACTION NEEDED). Re-run this script afterwards to confirm."
exit 0
