#!/usr/bin/env bash
# Fails when a tracked file holds a name on the private deny list.
# The list is .github/denyhash.txt: the sha256 of each lowercased name, one
# per line, so the names themselves never appear in this repo.
# Usage: scripts/check-names.sh            (every tracked file)
#        scripts/check-names.sh --staged   (the staged version of each file)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
list=.github/denyhash.txt
[ -f "$list" ] || { echo "check-names: $list missing" >&2; exit 2; }
mode=${1:-}
python3 - "$list" "$mode" <<'PY'
import hashlib, re, subprocess, sys
deny = {l.strip() for l in open(sys.argv[1]) if l.strip()}
staged = sys.argv[2] == "--staged"
def h(s): return hashlib.sha256(s.encode()).hexdigest()
if staged:
    files = subprocess.run(["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z"], capture_output=True, check=True).stdout.split(b"\0")
else:
    files = subprocess.run(["git", "ls-files", "-z"], capture_output=True, check=True).stdout.split(b"\0")
tok = re.compile(r"[a-z0-9_.@/-]+")
word = re.compile(r"[a-z0-9_]+")
bad = 0
for f in filter(None, files):
    name = f.decode("utf-8", "replace")
    if name == sys.argv[1]:
        continue
    try:
        data = subprocess.run(["git", "show", ":" + name], capture_output=True, check=True).stdout if staged else open(f, "rb").read()
    except Exception:
        continue
    if b"\0" in data[:8000]:
        continue
    text = (name + "\n" + data.decode("utf-8", "replace")).lower()
    for n, line in enumerate(text.split("\n")):
        cands = set()
        for t in tok.findall(line):
            t = t.strip("./-@")
            cands.add(t)
            parts = [p for p in re.split(r"[/@]", t) if p]
            cands.update(parts)
            for p in parts:
                d = p.split(".")
                cands.update(d)
                cands.update(".".join(d[i:j]) for i in range(len(d)) for j in range(i + 2, len(d) + 1))
                cands.update(re.split(r"[-.]", p))
            cands.update(re.split(r"[^a-z0-9_]", t))
        ws = word.findall(line)
        cands.update(a + " " + b for a, b in zip(ws, ws[1:]))
        for c in cands:
            if c and h(c) in deny:
                where = "path" if n == 0 else f"line {n}"
                print(f"check-names: {name} ({where}) holds a private name (hash {h(c)[:12]})", file=sys.stderr)
                bad += 1
if bad:
    print(f"check-names: {bad} hit(s); replace them with generic names (acme, example.com, alice)", file=sys.stderr)
    sys.exit(1)
print("check-names: ok")
PY
