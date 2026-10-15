#!/usr/bin/env bash
# ============================================================================
# Session branch guard — stops a commit or push when the folder's branch was
# moved by something other than this session (another Claude session in the
# same folder, or a manual switch).
#
#   session-branch.sh record   PostToolUse / PostToolUseFailure(Bash): remember
#                              this session's branch
#   session-branch.sh check    called by pre-bash-guard.sh; prints a refusal
#                              reason on a mismatch, nothing otherwise
#
# The record follows the branch only when this session itself moves it (git
# switch, git checkout <branch>, -b, git branch -m, git rebase <up> <branch>,
# gh pr checkout, gh pr merge --delete-branch, gh issue develop --checkout) and
# the folder ended up on that command's target, or when it has no record yet.
# Following it on every command would let a routine `git status` after another
# session's switch quietly accept the wrong branch.
#
# Not seen: git run from a script, alias, shell function or backticks. A move
# made that way is refused once; `git switch <branch>` accepts it.
#
# Records: <git dir>/proof-sessions/<session id>, one line, the branch name.
# The git dir is per worktree, never committed. Untouched for 30 days = removed.
#
# Fails open: anything unexpected (no session id, not a repo, detached HEAD,
# a folder it cannot resolve) records nothing and refuses nothing. A command
# the parser cannot read falls back to a plain line-by-line scan.
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
PREFIX_WORDS = ("then", "do", "else", "elif", "if", "while", "until", "{", "!", "time",
                "command", "builtin", "exec", "nohup")
WRAPPERS = ("env", "sudo", "xargs", "timeout")   # skipped along with their options
SHELLS = ("bash", "sh", "zsh")
HEREDOC = re.compile(r"<<(?!<)(-?)[ \t]*\\?(['\"]?)([A-Za-z_][A-Za-z0-9_.-]*)\2(?=[\s;|&<>)]|$)")
FD_REDIRECT = re.compile(r"(^|[\s;&|(])\d+(?=[<>])")   # the 2 in 2>&1
TOPLEVEL = ("$PWD", "${PWD}", "$(pwd)", "$(git rev-parse --show-toplevel)")


def git(d, *args):
    try:
        r = subprocess.run(["git", "-C", d] + list(args), stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL, universal_newlines=True, timeout=3)
    except Exception:
        return None
    if r.returncode != 0:
        return None
    return r.stdout.strip() or None


_branches = {}


def is_branch(d, name):
    """A local branch, or one git will create from a remote of the same name."""
    if (d, name) not in _branches:
        _branches[(d, name)] = _is_branch(d, name)
    return _branches[(d, name)]


def _is_branch(d, name):
    if name == "HEAD":
        return False
    try:
        if subprocess.call(["git", "-C", d, "show-ref", "--verify", "--quiet", "refs/heads/" + name],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3) == 0:
            return True
    except Exception:
        return False
    remote = git(d, "for-each-ref", "--format=%(refname:lstrip=3)", "refs/remotes")
    return bool(remote) and name in remote.split("\n")


def heredocs_in(line, stack):
    """The heredoc operators on this line that the shell would act on: not
    inside quotes or after a comment. `stack` carries quoting across lines
    ("" top level, ' or " a quote, ( a $( ) substitution) and is updated."""
    found, i, n = [], 0, len(line)
    while i < n:
        c, top = line[i], stack[-1]
        if top == "'":
            if c == "'":
                stack.pop()
        elif top == "$'":   # $'...': a backslash escapes, \' included
            if c == "\\":
                i += 1
            elif c == "'":
                stack.pop()
        elif top == "((":   # arithmetic: << is a shift, not a heredoc
            if line.startswith("))", i):
                stack.pop()
                i += 1
        elif top == '"':
            if c == "\\":
                i += 1
            elif c == '"':
                stack.pop()
            elif line.startswith("$((", i):
                stack.append("((")
                i += 2
            elif line.startswith("$(", i):
                stack.append("(")
                i += 1
        elif c == "\\":
            i += 1
        elif line.startswith("$'", i):
            stack.append("$'")
            i += 1
        elif c in "'\"":
            stack.append(c)
        elif line.startswith("$((", i) or line.startswith("((", i):
            stack.append("((")
            i += 2 if c == "$" else 1
        elif line.startswith("$(", i):
            stack.append("(")
            i += 1
        elif c == ")" and top == "(":
            stack.pop()
        elif c == "#" and (i == 0 or line[i - 1] in " \t"):
            break
        elif c == "<" and (i == 0 or line[i - 1] != "<"):
            m = HEREDOC.match(line, i)
            if m:
                found.append((m.group(1) == "-", m.group(3)))
                i = m.end()
                continue
        i += 1
    return found


def strip_heredocs(cmd):
    """Drop heredoc bodies and their end lines: they are data, not commands, and
    an apostrophe in one would otherwise break the parse."""
    out, pending, stack = [], [], [""]
    for line in cmd.split("\n"):
        if pending:
            dash, word = pending[0]
            if (line.lstrip("\t") if dash else line) == word:
                pending.pop(0)
            continue
        out.append(line)
        pending.extend(heredocs_in(line, stack))
    return "\n".join(out)


def commands(cmd):
    """Split into simple commands (lists of words), quote-aware. Subshell
    parentheses come through as ("(" | ")", None) markers."""
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=PUNCT)
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    lex.commenters = ""
    out, cur, skip_next = [], [], False
    for tok in lex:
        if tok and all(c in PUNCT for c in tok):
            if tok[0] in "<>" or tok.startswith("&>"):
                skip_next = True   # the next word is a file name or heredoc delimiter
                continue
            if cur:
                out.append(cur)
                cur = []
            for c in tok:
                if c in "()":
                    out.append((c, None))
            continue
        if skip_next:
            skip_next = False
            continue
        cur.append(tok)
    if cur:
        out.append(cur)
    return out


def strip_prefix(words):
    """Drop shell keywords, VAR=value assignments and wrappers in front of the
    command. Returns (words, elsewhere): elsewhere when GIT_DIR or GIT_WORK_TREE
    points git at another repo."""
    i, elsewhere = 0, False
    while i < len(words):
        w = words[i]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w):
            elsewhere = elsewhere or w.startswith(("GIT_DIR=", "GIT_WORK_TREE="))
            i += 1
        elif w in PREFIX_WORDS:
            i += 1
        elif w in WRAPPERS:
            i += 1
            while i < len(words) and words[i].startswith("-"):
                i += 1
            if w == "timeout":
                i += 1   # the duration
        else:
            break
    return words[i:], elsewhere


def positional(args):
    return [a for a in args if a == "-" or not a.startswith("-")]


def value_of(args, flags):
    for i, a in enumerate(args):
        if a in flags:
            return args[i + 1] if i + 1 < len(args) else None
        for f in flags:
            if f.startswith("--") and a.startswith(f + "="):
                return a.split("=", 1)[1]
    return None


def literal(name):
    """A branch name as written, or None when the shell fills it in ($BR, @{-1})."""
    return None if name is None or re.search(r"[$`*?\[]|@\{", name) else name


def switch_info(sub, args, d, branch):
    """(moves the branch?, the branch it moves to, or None if it can't tell)."""
    if sub == "gh-switch":
        return True, None
    if "-h" in args or "--help" in args:
        return False, None
    pos = positional(args)
    if sub == "switch":
        new = value_of(args, ("-c", "-C", "--create", "--force-create", "--orphan"))
        if new:
            return True, literal(new)
        if any(a in ("-d", "--detach", "-t", "--track") for a in args) or not pos or pos[0] == "-":
            return True, None
        return True, literal(pos[0])
    if sub == "checkout":
        new = value_of(args, ("-b", "-B", "--orphan"))
        if new:
            return True, literal(new)
        if any(a in ("-t", "--track", "--detach") for a in args):
            return True, None
        if any(a in ("--", "-p", "--patch") for a in args) or len(pos) != 1:
            return False, None   # restoring files, not switching
        if pos[0] == "-" or literal(pos[0]) is None:
            return True, None
        return (True, pos[0]) if is_branch(d, pos[0]) else (False, None)
    if sub == "branch":
        if not any(a in ("-m", "-M", "--move") for a in args):
            return False, None
        if len(pos) == 1:
            return True, literal(pos[0])
        if len(pos) == 2:
            # Renames the current branch only if the old name is the current one:
            # before it runs that is `branch`; after, the new name is.
            return (MODE == "record" or pos[0] == branch or literal(pos[0]) is None), literal(pos[1])
        return False, None
    if sub == "rebase":
        onto = value_of(args, ("--onto",))
        if onto in pos:
            pos.remove(onto)
        return (True, literal(pos[1])) if len(pos) == 2 else (False, None)
    return False, None


class Walker:
    """Walks a command's parts in order, tracking the folder each one runs in."""

    def __init__(self, cwd):
        self.cwd = cwd
        self.tops = {}
        self.home = self.top(cwd)

    def top(self, d):
        if d is None:
            return None
        if d not in self.tops:
            self.tops[d] = git(d, "rev-parse", "--show-toplevel")
        return self.tops[d]

    def same_repo(self, d):
        return d is not None and self.home is not None and (d == self.cwd or self.top(d) == self.home)

    def resolve(self, base, path):
        if base is None:
            return None
        if path in TOPLEVEL:
            return self.top(base) or base
        if not path or "$" in path or "`" in path:
            return None
        path = os.path.expanduser(path)
        p = os.path.normpath(path if os.path.isabs(path) else os.path.join(base, path))
        if MODE == "record" and not os.path.isabs(path) and not (os.path.isdir(p) and self.same_repo(p)):
            # The hook's cwd may already be past this cd. A wrong guess is
            # harmless: the record only moves to the branch the command named.
            return base
        return p if os.path.isdir(p) else None

    def git_parts(self, cmd, d=None, depth=0):
        """Yield (folder or None, subcommand, args) for each git command, plus
        ("gh-switch") for gh commands that move the branch."""
        d = self.cwd if d is None else d
        subshells, pushed, prev = [], [], d
        for words in commands(FD_REDIRECT.sub(r"\1", strip_heredocs(cmd).replace("\\\n", " "))):
            if isinstance(words, tuple):
                if words[0] == "(":
                    subshells.append(d)
                elif subshells:
                    d = subshells.pop()
                continue
            words, elsewhere = strip_prefix(words)
            if not words:
                continue
            name = os.path.basename(words[0])
            if name in ("cd", "pushd", "popd"):
                args = [w for w in words[1:] if w == "-" or not w.startswith("-")]
                if name == "popd":
                    new = pushed.pop() if pushed else None
                elif not args:
                    new = os.path.expanduser("~")
                elif args[0] == "-":
                    new = prev
                else:
                    new = self.resolve(d, args[0])
                if name == "pushd":
                    pushed.append(d)
                prev, d = d, new
            elif name in SHELLS and depth < 3:
                for j in range(1, len(words) - 1):
                    if re.match(r"^-[a-z]*c[a-z]*$", words[j]):
                        for part in self.git_parts(words[j + 1], d, depth + 1):
                            yield part
                        break
            elif name == "eval" and depth < 3:
                for part in self.git_parts(" ".join(words[1:]), d, depth + 1):
                    yield part
            elif name == "gh":
                rest = words[1:]
                while rest and rest[0].startswith("-"):
                    rest = rest[2:] if rest[0] in ("-R", "--repo") else rest[1:]
                if rest[:2] == ["pr", "checkout"] or \
                        (rest[:2] == ["pr", "merge"] and any(a in ("-d", "--delete-branch") for a in rest)) or \
                        (rest[:2] == ["issue", "develop"] and any(a in ("-c", "--checkout") for a in rest)):
                    yield (None if elsewhere else d), "gh-switch", []
            elif name == "git":
                target, i = (None if elsewhere else d), 1
                while i < len(words):
                    w = words[i]
                    if w == "-C" and i + 1 < len(words):
                        target = self.resolve(target, words[i + 1])
                        i += 2
                    elif w in ("-c", "--git-dir", "--work-tree", "--namespace"):
                        if w != "-c":
                            target = None
                        i += 2
                    elif w.startswith(("--git-dir=", "--work-tree=")):
                        target = None
                        i += 1
                    elif w.startswith("-"):
                        i += 1
                    else:
                        break
                if i < len(words):
                    yield target, words[i], words[i + 1:]


ROUGH_GIT = r"^(\S+=\S*\s+)*((sudo|env|command|exec|nohup)\s+)*\S*\bgit(\s+-\S+)*\s+"


def rough_scan(cmd):
    """Fallback for a command the parser can't read: line-by-line, no folder
    tracking. Returns (switches, commit_or_push_before_any_switch), or None when
    the command changes folder or points git elsewhere — then it can't tell."""
    text = strip_heredocs(cmd)
    if re.search(r"(^|[\s;&|(])(cd|pushd|popd)(\s|$)|\s-C\s|GIT_DIR=|GIT_WORK_TREE=|--git-dir|--work-tree", text):
        return None
    switched, unguarded = False, False
    for part in re.split(r"&&|\|\||;|\||\n", text):
        p = part.strip().lstrip("({ ")
        if re.match(ROUGH_GIT + r"(switch|checkout)\b", p) or re.match(r"^gh\s+pr\s+checkout\b", p):
            switched = True
        elif re.match(ROUGH_GIT + r"(commit|push)\b", p) and not switched:
            unguarded = True
    return switched, unguarded


def refusal(branch, recorded):
    return ("Refused: this folder is on branch '%s', but this session last put it on "
            "'%s'. Another session, or a manual switch, may have moved it, so this "
            "commit or push could land on the wrong branch or pull request. Do not "
            "switch back on your own: ask the user which branch this work belongs on. "
            "If '%s' is right, accept it with `git switch %s`, then retry."
            % (branch, recorded, branch, branch))


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
            recorded = f.readline().strip() or None
    except Exception:
        recorded = None

    walker = Walker(cwd)

    if MODE == "check":
        if not branch or not recorded or recorded == branch:
            return
        try:
            switched = False
            for d, sub, args in walker.git_parts(cmd):
                if not walker.same_repo(d):
                    continue
                if switch_info(sub, args, d, branch)[0]:
                    switched = True
                elif sub in ("commit", "push") and not switched:
                    print(refusal(branch, recorded))
                    return
        except ValueError:   # shlex: unbalanced quotes
            rough = rough_scan(cmd)
            if rough and rough[1]:
                print(refusal(branch, recorded))
        except Exception:
            pass
        return

    # record
    try:
        os.makedirs(folder, exist_ok=True)
    except Exception:
        return
    cutoff = time.time() - KEEP_DAYS * 86400
    for name in os.listdir(folder):
        p = os.path.join(folder, name)
        try:
            if name != sid and os.path.isfile(p) and os.path.getmtime(p) < cutoff:
                os.remove(p)
        except Exception:
            pass   # another session swept it first
    write = False
    if branch:
        if recorded is None:
            write = True
        else:
            try:
                for d, sub, args in walker.git_parts(cmd):
                    if walker.same_repo(d):
                        moves, target = switch_info(sub, args, d, branch)
                        # Only follow a move that landed where the command said.
                        if moves and target in (None, branch):
                            write = True
            except ValueError:
                rough = rough_scan(cmd)
                write = bool(rough and rough[0])
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
