#!/usr/bin/env bash
# ============================================================================
# Session branch guard — stops a commit or push when the folder's branch was
# moved by something other than this session (another Claude session in the
# same folder, or a manual switch).
#
#   session-branch.sh record   PostToolUse(Bash): remember this session's branch
#   session-branch.sh check    called by pre-bash-guard.sh; prints a refusal
#                              reason on a mismatch, nothing otherwise
#
# The record follows the branch only when this session itself switches
# (git switch, git checkout <branch>, -b ...) or has no record yet. Following
# it on every command would let a routine `git status` after another session's
# switch quietly accept the wrong branch.
#
# Records: <git dir>/proof-sessions/<session id>, one line, the branch name.
# The git dir is per worktree, never committed. Untouched for 30 days = removed.
#
# Fails open: anything unexpected (no session id, not a repo, detached HEAD,
# a command it cannot parse) records nothing and refuses nothing.
#
# Must run on macOS's stock bash 3.2 — the Python is read with `read -d ''`,
# not $(cat <<EOF), which 3.2 mis-parses.
# Regression cases: tests/session-branch.test.sh
# ============================================================================
set -uo pipefail

MODE="${1:-}"
case "$MODE" in record|check) ;; *) exit 0 ;; esac

INPUT="$(cat)"

read -r -d '' PY <<'PYEOF'
import json, os, re, shlex, subprocess, sys, time

MODE = sys.argv[1]
KEEP_DAYS = 30
PUNCT = "();<>|&\n"


def git(d, *args):
    try:
        r = subprocess.run(["git", "-C", d] + list(args), stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL, universal_newlines=True, timeout=3)
    except Exception:
        return None
    if r.returncode != 0:
        return None
    return r.stdout.strip() or None


def commands(cmd):
    """Split a shell command into simple commands (lists of words), quote-aware.
    Yields ("(" | ")", None) markers for subshells. Skips unquoted heredoc bodies."""
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=PUNCT)
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    lex.commenters = ""
    out, cur = [], []
    skip_next = False   # the word after a redirect is a file name, not a command word
    heredocs = []       # delimiters waiting for their body to start
    in_body = None      # delimiter of the heredoc body being skipped
    line = []
    for tok in lex:
        if in_body is not None:
            if tok == "\n":
                if line == [in_body]:
                    heredocs.pop(0)
                    in_body = heredocs[0] if heredocs else None
                line = []
            else:
                line.append(tok)
            continue
        if tok and all(c in PUNCT for c in tok):
            if tok[0] in "<>" or tok.startswith("&>"):
                if tok.startswith("<<") and not tok.startswith("<<<"):
                    heredocs.append(None)   # filled in by the next word
                skip_next = True
                continue
            if cur:
                out.append(cur)
                cur = []
            for c in tok:
                if c in "()":
                    out.append((c, None))
            if "\n" in tok and heredocs:
                in_body = heredocs[0]
                line = []
            continue
        if skip_next:
            skip_next = False
            if heredocs and heredocs[-1] is None:
                heredocs[-1] = tok.lstrip("-")
            continue
        cur.append(tok)
    if cur:
        out.append(cur)
    return out


def strip_prefix(words):
    i = 0
    while i < len(words):
        w = words[i]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w) or w in ("env", "command", "builtin",
                                                             "exec", "time", "nohup", "!"):
            i += 1
            continue
        break
    return words[i:]


class Walker:
    """Walks a command's parts in order, tracking the directory each one runs in."""

    def __init__(self, cwd, after):
        self.cwd = cwd
        self.after = after   # record mode: the hook's cwd may already reflect a cd
        self.tops = {}

    def resolve(self, base, path):
        if base is None or not path or path == "-" or "$" in path or "`" in path:
            return None
        path = os.path.expanduser(path)
        p = os.path.normpath(path if os.path.isabs(path) else os.path.join(base, path))
        if os.path.isdir(p):
            return p
        if self.after and not os.path.isabs(path):
            return base   # the shell already moved there; the hook cwd is the target
        return None

    def top(self, d):
        if d is None:
            return None
        if d not in self.tops:
            self.tops[d] = git(d, "rev-parse", "--show-toplevel")
        return self.tops[d]

    def same_repo(self, d, home_top):
        return d is not None and home_top is not None and (d == self.cwd or self.top(d) == home_top)

    def git_parts(self, cmd):
        """Yield (dir, subcommand, args) for each git command, dir None if unknown."""
        d, stack = self.cwd, []
        for words in commands(cmd):
            if isinstance(words, tuple):
                if words[0] == "(":
                    stack.append(d)
                elif stack:
                    d = stack.pop()
                continue
            words = strip_prefix(words)
            if not words:
                continue
            if words[0] in ("cd", "pushd"):
                args = [w for w in words[1:] if not w.startswith("-") or w == "-"]
                d = self.resolve(d, args[0]) if args else os.path.expanduser("~")
                continue
            if words[0] != "git":
                continue
            target, i = d, 1
            while i < len(words):
                w = words[i]
                if w == "-C" and i + 1 < len(words):
                    target = self.resolve(target, words[i + 1])
                    i += 2
                elif w in ("-c", "--git-dir", "--work-tree", "--namespace"):
                    if w != "-c":
                        target = None
                    i += 2
                elif w.startswith("--git-dir=") or w.startswith("--work-tree="):
                    target = None
                    i += 1
                elif w.startswith("-"):
                    i += 1
                else:
                    break
            if i < len(words):
                yield target, words[i], words[i + 1:]


def is_switch(sub, args, d):
    if sub == "switch":
        return True
    if sub != "checkout":
        return False
    if any(a in ("-b", "-B", "--orphan", "-t", "--track", "--detach") for a in args):
        return True
    if "--" in args:
        return False
    names = [a for a in args if not a.startswith("-") or a == "-"]
    if not names:
        return False
    if names[0] == "-":
        return True
    try:
        if subprocess.call(["git", "-C", d, "show-ref", "--verify", "--quiet", "refs/heads/" + names[0]],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3) == 0:
            return True
    except Exception:
        return False
    # Before it runs, a name that is neither a branch nor a file is a branch git
    # will create from a remote. After it runs, it would already be local.
    return MODE == "check" and not os.path.exists(os.path.join(d, names[0]))


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    sid = str(data.get("session_id") or "")
    cwd = data.get("cwd") or ""
    cmd = (data.get("tool_input") or {}).get("command") or ""
    sid = re.sub(r"[^A-Za-z0-9._-]", "_", sid).lstrip(".")
    if not sid or not cwd or not os.path.isdir(cwd):
        return
    if MODE == "check" and "git" not in cmd:
        return

    gitdir = git(cwd, "rev-parse", "--absolute-git-dir")
    if not gitdir:
        return
    branch = git(cwd, "symbolic-ref", "--short", "-q", "HEAD")
    folder = os.path.join(gitdir, "proof-sessions")
    path = os.path.join(folder, sid)
    try:
        with open(path) as f:
            recorded = f.read().strip()
    except Exception:
        recorded = None

    walker = Walker(cwd, after=(MODE == "record"))
    home_top = walker.top(cwd)

    if MODE == "check":
        if not branch or not recorded or recorded == branch:
            return
        switched = False
        try:
            for d, sub, args in walker.git_parts(cmd):
                if not walker.same_repo(d, home_top):
                    continue
                if is_switch(sub, args, d):
                    switched = True
                elif sub in ("commit", "push") and not switched:
                    print(
                        "Refused: this folder is on branch '%s', but this session last put it on "
                        "'%s'. Another session, or a manual switch, may have moved it, so this "
                        "commit or push could land on the wrong branch or pull request. Do not "
                        "switch back on your own: ask the user which branch this work belongs on. "
                        "If '%s' is right, accept it with `git switch %s`, then retry."
                        % (branch, recorded, branch, branch))
                    return
        except Exception:
            return
        return

    # record
    try:
        os.makedirs(folder, exist_ok=True)
        cutoff = time.time() - KEEP_DAYS * 86400
        for name in os.listdir(folder):
            p = os.path.join(folder, name)
            if name != sid and os.path.isfile(p) and os.path.getmtime(p) < cutoff:
                os.remove(p)
    except Exception:
        return
    write = False
    if branch:
        if recorded is None:
            write = True
        elif "git" in cmd:
            try:
                write = any(walker.same_repo(d, home_top) and is_switch(sub, args, d)
                            for d, sub, args in walker.git_parts(cmd))
            except Exception:
                write = False
    try:
        if write:
            tmp = path + ".tmp"
            with open(tmp, "w") as f:
                f.write(branch + "\n")
            os.replace(tmp, path)
        elif recorded is not None:
            os.utime(path, None)   # still in use: keep it past the 30-day sweep
    except Exception:
        pass


main()
PYEOF

printf '%s' "$INPUT" | python3 -c "$PY" "$MODE" 2>/dev/null
exit 0
