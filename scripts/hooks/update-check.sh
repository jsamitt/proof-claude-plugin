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
# with a 3-second limit and a 64 KB cap; a failed lookup also counts for the
# day, and no lookup happens at all when the day's answer can't be saved.
#
# Data: <data dir>/update-check.json (the day's answer) and skipped.json (the
# versions turned down, per install). The data dir is CLAUDE_PLUGIN_DATA,
# outside every repo; never Claude Code's own records.
#
# Silent on every error, up to date, offline, or a slow lookup: no output,
# exit 0, the session starts normally. The whole check gives up after 4 seconds.
#
# Python runs isolated (-I): with plain -c it would import a json.py or re.py
# from the project folder the hook runs in.
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
export PROOF_DATA="${CLAUDE_PLUGIN_DATA:-$CONFIG/proof-data}"
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
VERSION = re.compile(r"v?([0-9]{1,9}(?:\.[0-9]{1,9}){0,5})")
NAME = r"[A-Za-z0-9_][A-Za-z0-9_.-]*"
REPO = re.compile(NAME + "/" + NAME)
KEY = re.compile(NAME + "@" + NAME)
MAX_BYTES = 64 * 1024
DEADLINE = 4
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
    """(0, 10, 0) for "0.10.0", else None. ASCII digits only."""
    if not isinstance(v, str):
        return None
    m = VERSION.fullmatch(v.strip(" \t\r\n"))
    return tuple(int(x) for x in m.group(1).split(".")) if m else None


def clean(v):
    """The version as it is shown and stored: "0.10.0", never the raw text."""
    t = parse(v)
    return ".".join(str(x) for x in t) if t else None


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
    best, best_depth = None, -1
    for e in entries:
        if not isinstance(e, dict):
            continue
        pp = e.get("projectPath")
        if e.get("scope") in ("project", "local") and isinstance(pp, str) and os.path.isabs(pp):
            if any(inside(f, pp) or inside(f, real(pp)) for f in folders):
                depth = len(real(pp).rstrip("/"))
                if best is None or depth > best_depth:
                    best, best_depth = e, depth
    if best is not None:
        return best
    for e in entries:
        if isinstance(e, dict) and e.get("scope") == "user":
            return e
    return None


def fetch(url):
    """The version field of plugin.json at url, or None. 3-second limit."""
    try:
        p = subprocess.Popen(["curl", "-fsSL", "--max-redirs", "3", "--proto", "=https,file",
                              "--max-filesize", str(MAX_BYTES), "-m", "3", url],
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                             start_new_session=True)
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
    if p.returncode != 0 or len(out) > MAX_BYTES:
        return None
    try:
        return clean(json.loads(out.decode("utf-8")).get("version"))
    except Exception:
        return None


def latest(data, url):
    """The day's answer from the cache, else one lookup, saved for the day."""
    today = time.strftime("%Y-%m-%d")
    path = os.path.join(data, CACHE)
    try:
        c = load(path)
        if c.get("date") == today and c.get("url") == url:
            return clean(c.get("latest"))
    except Exception:
        pass
    # Claim the day first: if it can't be saved, every session would look it up
    # again, so don't look it up at all.
    try:
        os.makedirs(data, exist_ok=True)
        save(path, {"date": today, "url": url, "latest": None})
    except Exception:
        return None
    v = fetch(url)
    try:
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
        update = "claude plugin update %s" % key   # key is validated: KEY
        where = "the user install"
    else:
        install = entry["projectPath"]
        update = "cd %s && claude plugin update %s --scope %s" % (q(install), key, scope)
        where = "this project's own install (%s)" % json.dumps(install)
    skip = "%s skip %s %s %s" % (q(os.path.join(root, "scripts", "hooks", "update-check.sh")),
                                 q(data), q(install), q(new))
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


class Deadline(Exception):
    pass


def give_up(*_):
    raise Deadline()


def check():
    signal.signal(signal.SIGALRM, give_up)
    signal.alarm(DEADLINE)
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
    if not key or not KEY.fullmatch(key) or not isinstance(plugins.get(key), list):
        return
    entry = which_install(plugins[key], cwd)
    if entry is None:
        return
    current = clean(entry.get("version"))
    if not current:
        return
    source = (load(ENV["PROOF_MARKETS"]).get(key.split("@", 1)[1]) or {}).get("source") or {}
    repo = source.get("repo")
    if source.get("source") != "github" or not isinstance(repo, str) or not REPO.fullmatch(repo):
        return
    new = latest(data, ENV["PROOF_URL"].replace("{repo}", repo))
    if not new or not newer(parse(new), parse(current)):
        return
    install = "user" if entry.get("scope") == "user" else entry.get("projectPath")
    if new in [clean(v) for v in skipped(data, install)]:
        return
    signal.alarm(0)
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": offer(key, entry, current, new, root, data)}}))


def skip(args):
    if len(args) != 3:
        return 2
    data, install, version = args
    version = clean(version)
    if not os.path.isabs(data) or not version or not (install == "user" or os.path.isabs(install)):
        print("Not recorded: expected skip <absolute data dir> <user | absolute folder> <version>.")
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
        print("Not recorded: could not write %s." % path)
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
  python3 -I -c "$PY" skip "$@" 2>/dev/null
  exit $?
fi
printf '%s' "$INPUT" | python3 -I -c "$PY" check 2>/dev/null
exit 0
