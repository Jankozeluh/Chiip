#!/usr/bin/env python3
"""Scans the whole git history for things that must not become public (M12, D-180).

    python3 -I tools/scan_history.py            # every commit reachable from any branch (git log --all)
    python3 -I tools/scan_history.py main       # only what a push of main would publish

Looks in every line a commit ever added for keys and tokens (AWS, GitHub, Slack, Google, OpenAI-style,
private key blocks, JWTs), passwords and secrets assigned to a text, e-mail addresses, IP addresses
outside private ranges, and the home-folder paths of a person (macOS, Linux, Windows); in the file
names of every commit for key, certificate, credential, settings and archive files; in the commit
authors and messages; and lists the biggest files that were ever stored. It prints what it found and
exits with the number of kinds of finding that need a look (keys, tokens, secrets, e-mails, bad file
names). Paths and big files are reported but don't change the exit code. It only reads the
repository; it needs Python 3 and git, nothing else. docs/RELEASE_CHECKLIST.md, section 9.
"""
import collections
import re
import subprocess
import sys

REFS = sys.argv[1:] or ["--all"]

PATTERNS = {
    "aws key": (re.compile(r"AKIA[0-9A-Z]{16}"), True),
    "github token": (re.compile(r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}"), True),
    "slack token": (re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"), True),
    "openai or anthropic style key": (re.compile(r"\bsk-[A-Za-z0-9_-]{20,}"), True),
    "google api key": (re.compile(r"AIza[0-9A-Za-z_-]{35}"), True),
    "private key block": (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), True),
    "json web token": (re.compile(r"\beyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{10,}\."), True),
    "secret assigned to a text": (re.compile(r"(?i)\b(?:password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token)\b\s*[:=]\s*[\"'][^\"'\s]{8,}[\"']"), True),
    "e-mail address": (re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z]{2,}\b"), True),
    "home path (macOS)": (re.compile(r"/Us" r"ers/[A-Za-z0-9._-]+"), False),  # split, so this file doesn't contain what it looks for
    "home path (Linux)": (re.compile(r"/home/[a-z][a-z0-9_-]+"), False),
    "home path (Windows)": (re.compile(r"[A-Za-z]:\\{1,2}Users\\{1,2}[A-Za-z0-9._-]+"), False),
    "public IP address": (re.compile(r"\b(?!127\.|0\.|10\.|192\.168\.|172\.(?:1[6-9]|2\d|3[01])\.|100\.|169\.254\.|255\.)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"), False),
}
BAD_NAMES = re.compile(r"(?i)\.(?:env|pem|key|p12|pfx|keystore|jks|cer|crt|kdbx|sqlite|db|log|bak|swp|zip|7z|rar|tar|gz|dmg|exe|dll|so|dylib|apk|ipa)$|credential|secret|id_rsa|id_ed25519|password|\.DS_Store|(?:^|/)settings\.cfg$|export_credentials|\.claude/settings")


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def scan_added_lines():
    process = subprocess.Popen(["git", "log", "-p", "--no-color", "--format=@@COMMIT %H"] + REFS, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    hits = collections.defaultdict(lambda: collections.defaultdict(set))
    commit = path = ""
    for raw in process.stdout:
        line = raw.decode("utf-8", "replace").rstrip("\n")
        if line.startswith("@@COMMIT "):
            commit = line[9:17]
        elif line.startswith("+++ b/"):
            path = line[6:]
        elif line.startswith("+") and not line.startswith("+++"):
            for name, (pattern, _serious) in PATTERNS.items():
                for match in pattern.finditer(line):
                    hits[name][match.group(0)[:60]].add((commit, path))
    return hits


def main():
    print("History scan of: %s (%s commits)" % (" ".join(REFS), git("rev-list", "--count", *REFS).strip()))
    serious = 0
    hits = scan_added_lines()
    for name, (_pattern, is_serious) in PATTERNS.items():
        found = hits.get(name, {})
        mark = "FOUND" if found and is_serious else ("note " if found else "none ")
        print("%s %-32s %d distinct" % (mark, name, len(found)))
        for text, where in sorted(found.items(), key=lambda item: -len(item[1]))[:6]:
            commits = {c for c, _ in where}
            files = sorted({p for _, p in where})
            print("        %-46s %3d commits, e.g. %s" % (text, len(commits), ", ".join(files[:2])))
        if found and is_serious:
            serious += 1
    names = sorted({n for n in git("log", "--name-only", "--format=", *REFS).split("\n") if n and BAD_NAMES.search(n)})
    print("%s %-32s %d" % ("FOUND" if names else "none ", "sensitive file names ever stored", len(names)))
    for name in names[:10]:
        print("        " + name)
    if names:
        serious += 1
    identities = collections.Counter(git("log", "--format=%an <%ae> | %cn <%ce>", *REFS).strip().split("\n"))
    print("note  commit identities:")
    for identity, count in identities.most_common():
        print("        %4d  %s" % (count, identity))
    messages = [m for m in git("log", "--format=%B", *REFS).split("\n") if re.search(r"(?i)password|token|secret|api.?key", m)]
    print("note  commit message lines that mention passwords, tokens, secrets or keys: %d (read them: %s)" % (len(messages), "; ".join(m[:60] for m in messages[:3])))
    blobs = []
    objects = subprocess.run("git rev-list --objects %s | git cat-file --batch-check='%%(objecttype) %%(objectsize) %%(rest)'" % " ".join(REFS), shell=True, capture_output=True, text=True).stdout
    for line in objects.split("\n"):
        parts = line.split(" ", 2)
        if len(parts) == 3 and parts[0] == "blob":
            blobs.append((int(parts[1]), parts[2]))
    blobs.sort(reverse=True)
    print("note  biggest files ever stored:")
    for size, name in blobs[:5]:
        print("        %6.2f MB  %s" % (size / 1048576, name))
    print("%d kind(s) of finding need a look." % serious)
    return serious


if __name__ == "__main__":
    sys.exit(main())
