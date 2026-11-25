#!/usr/bin/env bash
# check-names.sh: fail when text about to be committed or pushed holds a
# private name (client, company, teammate, server) from a local word list.
#
# The list is never stored in this repo. It is read from $NAMES_GUARD_FILE,
# else ~/.config/names-guard/terms.txt (one word or phrase per line, # for
# comments). Matching is whole-word and case-insensitive. Without a list the
# check prints one warning and passes. Generic words this repo really uses go
# in .github/names-allow.txt (one per line).
#
# Usage:
#   scripts/check-names.sh              tracked files, their paths and every commit message
#   scripts/check-names.sh --staged     lines added in the staged diff (pre-commit)
#   scripts/check-names.sh --msg FILE   one commit message (commit-msg)
#   scripts/check-names.sh --push       commits about to be pushed, read from the pre-push stdin
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
list=${NAMES_GUARD_FILE:-$HOME/.config/names-guard/terms.txt}
if [ ! -r "$list" ]; then
	echo "check-names: warning: no word list at $list, private-name check skipped" >&2
	exit 0
fi
exec python3 - "$list" "$@" <<'PY'
import re, subprocess, sys

list_file, args = sys.argv[1], sys.argv[2:]
mode = args[0] if args else "--all"

def git(*a, inp=None):
    return subprocess.run(["git", *a], capture_output=True, input=inp, check=True).stdout

def words(path):
    try:
        with open(path, encoding="utf-8") as f:
            return {l.strip().lower() for l in f if l.strip() and not l.lstrip().startswith("#")}
    except FileNotFoundError:
        return set()

terms = words(list_file) - words(".github/names-allow.txt")
if not terms:
    sys.exit(0)
alts = sorted((re.escape(t).replace(r"\ ", r"\s+") for t in terms), key=len, reverse=True)
pat = re.compile(r"(?<![A-Za-z0-9_])(?:" + "|".join(alts) + r")(?![A-Za-z0-9_])", re.I)
hits = []

def scan(where, text):
    for n, line in enumerate(text.splitlines(), 1):
        for m in pat.finditer(line):
            hits.append(f"{where}:{n}: {m.group(0)!r}")

def scan_diff(diff):
    path, n = "?", 0
    for line in diff.decode("utf-8", "replace").splitlines():
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else line[4:]
            scan("path", path)
        elif line.startswith("@@"):
            m = re.search(r"\+(\d+)", line)
            n = int(m.group(1)) - 1 if m else 0
        elif line.startswith("+"):
            n += 1
            for m in pat.finditer(line[1:]):
                hits.append(f"{path}:{n}: {m.group(0)!r}")
        elif not line.startswith("-"):
            n += 1

if mode == "--staged":
    scan_diff(git("diff", "--cached", "-U0", "--no-color", "--diff-filter=ACMR"))
elif mode == "--msg":
    with open(args[1], encoding="utf-8", errors="replace") as f:
        scan("commit message", "\n".join(l for l in f.read().splitlines() if not l.startswith("#")))
elif mode == "--push":
    zero = "0" * 40
    for line in sys.stdin.read().splitlines():
        parts = line.split()
        if len(parts) != 4 or parts[1] == zero:
            continue
        local, remote = parts[1], parts[3]
        rng = [local, "--not", "--remotes"] if remote == zero else [f"{remote}..{local}"]
        for c in git("rev-list", *rng).decode().split():
            scan(f"commit {c[:8]} message", git("log", "-1", "--format=%an %ae%n%B", c).decode("utf-8", "replace"))
            scan_diff(git("show", "--format=", "-U0", "--no-color", c))
else:
    for f in filter(None, git("ls-files", "-z").split(b"\0")):
        name = f.decode("utf-8", "replace")
        if name == ".github/names-allow.txt":
            continue
        scan("path", name)
        try:
            data = open(f, "rb").read()
        except OSError:
            continue
        if b"\0" not in data[:8000]:
            scan(name, data.decode("utf-8", "replace"))
    log = git("log", "--format=%h %an %ae%n%B%x00").decode("utf-8", "replace")
    for entry in filter(str.strip, log.split("\0")):
        scan(f"commit {entry.strip().split()[0]} message", entry)

if hits:
    print("check-names: private names found (replace them with generic ones such as acme, example.com, alice):", file=sys.stderr)
    for h in hits[:50]:
        print("  " + h, file=sys.stderr)
    if len(hits) > 50:
        print(f"  ... and {len(hits) - 50} more", file=sys.stderr)
    sys.exit(1)
print("check-names: ok")
PY
