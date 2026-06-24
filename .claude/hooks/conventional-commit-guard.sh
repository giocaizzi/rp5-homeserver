#!/usr/bin/env bash
# PreToolUse(Bash) guard — enforce Conventional Commits on commits the agent makes.
#
# We use Conventional Commits because release-please derives each component's
# version bump + changelog from the commit type (feat -> minor, fix -> patch,
# feat!/BREAKING CHANGE -> major). A non-conforming subject silently breaks the
# release automation, so we block it before the commit is created.
#
# Behaviour: inspect the Bash command on stdin (JSON). If it is a `git commit`
# with an inline -m/--message whose SUBJECT line is not a valid Conventional
# Commit, exit 2 (blocks the tool call, stderr is shown to the agent). Commits
# without an inline message (-F/template/--amend --no-edit) are not inspected.
#
# Read the hook payload from stdin FIRST, then hand the Python program the
# payload via an env var (the heredoc is Python's stdin, so it can't also carry
# the payload).
HOOK_PAYLOAD="$(cat)" python3 <<'PY'
import json, os, re, shlex, sys

try:
    data = json.loads(os.environ.get("HOOK_PAYLOAD", ""))
except Exception:
    sys.exit(0)

cmd = ((data.get("tool_input") or {}).get("command") or "")
if "git" not in cmd or "commit" not in cmd:
    sys.exit(0)

try:
    tokens = shlex.split(cmd)
except Exception:
    sys.exit(0)

if "git" not in tokens or "commit" not in tokens:
    sys.exit(0)

# Extract the first inline commit message (-m "..", --message=.., -m".." ).
msg = None
for i, t in enumerate(tokens):
    if t in ("-m", "--message") and i + 1 < len(tokens):
        msg = tokens[i + 1]
        break
    if t.startswith("--message="):
        msg = t.split("=", 1)[1]
        break
    if t.startswith("-m") and len(t) > 2:
        msg = t[2:]
        break

# No inline message -> not something we can/should validate here.
if not msg:
    sys.exit(0)

subject = msg.splitlines()[0].strip()

# Allow transient/auto subjects that are legitimately non-conventional.
if subject.startswith(("fixup!", "squash!", "Merge ", "Revert ")):
    sys.exit(0)

TYPES = "feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"
# Scope is MANDATORY (repo policy): main is squash-only and the PR title becomes
# the commit subject release-please parses, so every subject must be
# `type(scope): …`. The scope is any lowercase token — release-please attributes
# releases by file PATH, not scope, so the scope is advisory (prefer the component
# name where one applies). See AGENTS.md "Pull requests & commit titles".
SCOPE = r"[a-z][a-z0-9-]*"
pattern = rf"^({TYPES})\({SCOPE}\)!?: .+"
if re.match(pattern, subject):
    sys.exit(0)

sys.stderr.write(
    "Blocked: commit subject is not a Conventional Commit with a mandatory scope.\n\n"
    f"  Subject: {subject!r}\n\n"
    "Required: <type>(<scope>)[!]: <description>   (scope is MANDATORY, lowercase)\n"
    f"  type in  {{{TYPES.replace('|', ', ')}}}\n"
    "  scope: any lowercase token — a release-please component (infra, cloud, greenhouse, …)\n"
    "         or a meta scope (repo, cicd, deps, code)\n"
    "  e.g. 'feat(greenhouse): add humidity sensor', 'fix(infra): correct nginx healthcheck',\n"
    "       'chore(deps): bump actions/checkout', 'chore(infra)!: drop legacy config' (! = breaking)\n\n"
    "main is squash-only, so the PR title becomes the commit release-please parses;\n"
    "the type drives the version bump and the scope keeps attribution clear.\n"
)
sys.exit(2)
PY
