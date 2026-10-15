#!/usr/bin/env bash
# ============================================================================
# Update check — offers a newer Proof at the start of a new session.
#
#   update-check.sh                  SessionStart (startup only): when this
#                                    session's install is behind the latest
#                                    release, add a short offer to Claude's context
#   update-check.sh skip <data dir> <install> <version>
#                                    Claude runs this on "not now": that version
#                                    is never offered again for that install
#
# Which install: Claude Code's install record (installed_plugins.json). The
# entry for this plugin whose project folder most closely contains the session
# folder wins (a worktree with its own install is its own project); otherwise
# the user install.
#
# Latest version: plugin.json on the default branch of the GitHub repo the
# marketplace was added from (known_marketplaces.json -> source.repo). Nothing
# about the repo is written here. Looked up at most once a day per machine,
# with a 3-second limit; a failed lookup also counts for the day.
#
# Data: <data dir>/update-check.json (the day's answer) and skipped.json (the
# versions turned down, per install). The data dir is CLAUDE_PLUGIN_DATA,
# outside every repo; never Claude Code's own records.
#
# Silent on every error, up to date, offline, or a slow lookup: no output,
# exit 0, the session starts normally.
#
# Test overrides: PROOF_INSTALLED_PLUGINS, PROOF_KNOWN_MARKETPLACES and
# PROOF_LATEST_URL ({repo} is replaced by the marketplace repo; file:// works).
# Must run on macOS's stock bash 3.2 — the Python is read with `read -d ''`.
# Regression cases: tests/update-check.test.sh
# ============================================================================
set -uo pipefail

MODE="${1:-check}"
case "$MODE" in check|skip) ;; *) exit 0 ;; esac

CONFIG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
export PROOF_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
export PROOF_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/proof-data}"
export PROOF_INSTALLED="${PROOF_INSTALLED_PLUGINS:-$CONFIG/plugins/installed_plugins.json}"
export PROOF_MARKETS="${PROOF_KNOWN_MARKETPLACES:-$CONFIG/plugins/known_marketplaces.json}"
# In a variable: a literal } inside ${...:-...} would end the expansion early.
LATEST='https://raw.githubusercontent.com/{repo}/HEAD/.claude-plugin/plugin.json'
export PROOF_URL="${PROOF_LATEST_URL:-$LATEST}"

INPUT=""
[ "$MODE" = check ] && INPUT="$(cat)"

read -r -d '' PY <<'PYEOF'
import json, os, re, signal, subprocess, sys, time

ENV = os.environ
VERSION = re.compile(r"^v?(\d+(?:\.\d+)*)$")
REPO = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
CACHE = "update-check.json"
SKIPPED = "skipped.json"


def load(path):
    with open(path) as f:
        return json.load(f)


def save(path, data):
    """Atomic: a reader never sees half a file."""
    tmp = "%s.%d.tmp" % (path, os.getpid())
    with open(tmp, "w") as f:
        json.dump(data, f)
    os.replace(tmp, path)


def parse(v):
    m = VERSION.match(str(v or "").strip())
    return tuple(int(x) for x in m.group(1).split(".")) if m else None


def newer(a, b):
    """a > b, compared number by number (0.10.0 > 0.9.0)."""
    n = max(len(a), len(b))
    return a + (0,) * (n - len(a)) > b + (0,) * (n - len(b))


def q(s):
    return "'" + s.replace("'", "'\\''") + "'"


def real(p):
    try:
        return os.path.realpath(p)
    except Exception:
        return p


def plugin_key(plugins, root):
    """This plugin's key in the install record, e.g. name@marketplace: the
    entry installed at this plugin's folder, else the cache path's
    .../cache/<marketplace>/<plugin>/<version>."""
    r = real(root)
    for key, entries in plugins.items():
        for e in entries if isinstance(entries, list) else []:
            if isinstance(e, dict) and e.get("installPath") and real(e["installPath"]) == r:
                return key
    parts = r.rstrip("/").split("/")
    if len(parts) >= 4 and parts[-4] == "cache":
        key = "%s@%s" % (parts[-2], parts[-3])
        if key in plugins:
            return key
    return None


def inside(folder, project):
    project = project.rstrip("/") or "/"
    return folder == project or folder.startswith(project + "/")


def which_install(entries, cwd):
    """The project/local entry whose folder most closely contains cwd, else the
    user entry."""
    folders = set([cwd, real(cwd)])
    best = None
    for e in entries:
        if not isinstance(e, dict):
            continue
        pp = e.get("projectPath")
        if e.get("scope") in ("project", "local") and isinstance(pp, str) and os.path.isabs(pp):
            if any(inside(f, pp) or inside(f, real(pp)) for f in folders):
                if best is None or len(pp) > len(best["projectPath"]):
                    best = e
    if best is not None:
        return best
    for e in entries:
        if isinstance(e, dict) and e.get("scope") == "user":
            return e
    return None


def fetch(url):
    """The version field of plugin.json at url, or None. 3-second limit."""
    try:
        p = subprocess.Popen(["curl", "-fsS", "-m", "3", url], stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL, start_new_session=True)
    except Exception:
        return None
    try:
        out, _ = p.communicate(timeout=3.5)
    except Exception:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except Exception:
            pass
        return None
    if p.returncode != 0:
        return None
    try:
        v = json.loads(out.decode("utf-8")).get("version")
    except Exception:
        return None
    return v if parse(v) else None


def latest(data, url):
    """The day's answer from the cache, else one lookup, saved for the day."""
    today = time.strftime("%Y-%m-%d")
    path = os.path.join(data, CACHE)
    try:
        c = load(path)
        if c.get("date") == today and c.get("url") == url:
            return c.get("latest")
    except Exception:
        pass
    v = fetch(url)
    try:
        os.makedirs(data, exist_ok=True)
        save(path, {"date": today, "url": url, "latest": v})
    except Exception:
        pass
    return v


def skipped(data, install):
    try:
        s = load(os.path.join(data, SKIPPED)).get(install)
    except Exception:
        return []
    return s if isinstance(s, list) else []


def offer(key, entry, current, new, root, data):
    scope = entry.get("scope")
    if scope == "user":
        install = "user"
        update = "claude plugin update %s" % key
        where = "the user install"
    else:
        install = entry["projectPath"]
        update = "cd %s && claude plugin update %s --scope %s" % (q(install), key, scope)
        where = "this project's own install (%s)" % install
    skip = "%s skip %s %s %s" % (q(os.path.join(root, "scripts", "hooks", "update-check.sh")),
                                 q(data), q(install), new)
    return (
        "Proof update available: %(new)s is out; this session runs %(cur)s from %(where)s.\n"
        "At the very start of your first reply, in one line, say: \"Proof %(new)s is "
        "available (this project has %(cur)s). Update now?\" Then carry on with what the "
        "user asked; do not hold their request up for this, and do not raise it again.\n"
        "- If they say yes, run: %(update)s\n"
        "  Then tell them to restart Claude Code to use the new version.\n"
        "- If they say not now, run: %(skip)s\n"
        "  That version is then never offered again for this install."
        % {"new": new, "cur": current, "where": where, "update": update, "skip": skip})


def check():
    try:
        hook = json.loads(sys.stdin.read())
    except Exception:
        return
    if hook.get("source") != "startup":
        return
    cwd = hook.get("cwd") or ""
    root = ENV.get("PROOF_ROOT") or ""
    data = ENV.get("PROOF_DATA") or ""
    if not os.path.isabs(cwd) or not root or not os.path.isabs(data):
        return
    plugins = load(ENV["PROOF_INSTALLED"]).get("plugins")
    if not isinstance(plugins, dict):
        return
    key = plugin_key(plugins, root)
    if not key or "@" not in key:
        return
    entry = which_install(plugins[key], cwd)
    if entry is None:
        return
    current = entry.get("version")
    if not parse(current):
        return
    source = (load(ENV["PROOF_MARKETS"]).get(key.split("@", 1)[1]) or {}).get("source") or {}
    repo = source.get("repo")
    if source.get("source") != "github" or not isinstance(repo, str) or not REPO.match(repo):
        return
    new = latest(data, ENV["PROOF_URL"].replace("{repo}", repo))
    if not new or not newer(parse(new), parse(current)):
        return
    install = "user" if entry.get("scope") == "user" else entry.get("projectPath")
    if new in skipped(data, install):
        return
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": offer(key, entry, current, new, root, data)}}))


def skip(args):
    if len(args) != 3:
        return 2
    data, install, version = args
    if not os.path.isabs(data) or not parse(version) or not (install == "user" or os.path.isabs(install)):
        return 2
    path = os.path.join(data, SKIPPED)
    try:
        all_ = load(path)
        if not isinstance(all_, dict):
            all_ = {}
    except Exception:
        all_ = {}
    versions = all_.get(install) if isinstance(all_.get(install), list) else []
    if version not in versions:
        versions.append(version)
    all_[install] = versions
    try:
        os.makedirs(data, exist_ok=True)
        save(path, all_)
    except Exception:
        return 1
    print("Proof %s will not be offered again for this install." % version)
    return 0


if sys.argv[1] == "skip":
    sys.exit(skip(sys.argv[2:]))
try:
    check()
except Exception:
    pass
PYEOF

if [ "$MODE" = skip ]; then
  shift
  python3 -c "$PY" skip "$@" 2>/dev/null
  exit $?
fi
printf '%s' "$INPUT" | python3 -c "$PY" check 2>/dev/null
exit 0
