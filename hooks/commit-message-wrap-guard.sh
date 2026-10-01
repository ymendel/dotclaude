#!/usr/bin/env bash
# commit-message-wrap-guard.sh — PreToolUse (Bash) guard. Blocks a `git commit` whose -m body carries
# a line over 72 characters.
#
# `git commit -m` does not wrap. A long body passed as one -m string ships as one unwrapped line, and
# the commit succeeds, so nothing reports the defect until someone reads the log. commit-message-guide
# says so and gives the fix — a pre-broken string or `git commit -F <file>` — and the slip recurred
# anyway. Per rule-maintenance.md, guidance that is complete but keeps being bypassed earns a hook
# rather than more prose.
#
# What it checks: every line of every -m / --message value except the first line of the first one,
# which is the subject. Subjects are left alone on purpose — this repo's log has subjects past 72,
# which is a separate convention rather than this slip. The limit is 72, matching the guide.
#
# Parsing shell quoting is a parser's job, so the values come from Python's shlex rather than a regex.
# That costs an interpreter start, so it only happens when the command contains both `git commit` and
# a message flag — every other Bash call leaves after two string tests. A command shlex can't parse
# (an unbalanced quote, a heredoc) passes through: the guard fails open rather than blocking a commit
# it cannot read. `-F <file>` is not checked.
#
# Block mechanism is exit 2, so the message reaches Claude and the call stops before permission
# rules are evaluated.
#
# Checks live in hooks/test/run-checks.sh.

LIMIT=72

if ! command -v jq &>/dev/null || ! command -v python3 &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")

[[ "$CMD" == *"git commit"* ]] || exit 0
[[ "$CMD" == *"-m"* || "$CMD" == *"--message"* ]] || exit 0

FINDING=$(LIMIT="$LIMIT" python3 - "$CMD" <<'PY'
import os
import shlex
import sys

limit = int(os.environ["LIMIT"])
command = sys.argv[1]

try:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    tokens = list(lexer)
except ValueError:
    sys.exit(0)

separators = {"&&", "||", ";", "|", "&", ";;", "(", ")"}
segments, current = [], []
for token in tokens:
    if token in separators:
        segments.append(current)
        current = []
    else:
        current.append(token)
segments.append(current)

for segment in segments:
    if "git" not in segment or "commit" not in segment[segment.index("git"):]:
        continue
    messages = []
    words = iter(segment[segment.index("commit") + 1:])
    for word in words:
        if word in ("-m", "--message"):
            value = next(words, None)
            if value is not None:
                messages.append(value)
        elif word.startswith("--message="):
            messages.append(word[len("--message="):])
        elif word.startswith("-") and not word.startswith("--") and "m" in word[1:]:
            # Short flags combine: `-am "msg"` takes the next word, `-mmsg` and `-amsg` the rest of
            # this one. Anything before the `m` is a flag taking no value.
            rest = word[word.index("m", 1) + 1:]
            if rest:
                messages.append(rest)
            else:
                value = next(words, None)
                if value is not None:
                    messages.append(value)
    for index, message in enumerate(messages):
        lines = message.split("\n")
        if index == 0:
            lines = lines[1:]
        for line in lines:
            if len(line) > limit:
                print(f"{len(line)}\t{line[:60]}")
                sys.exit(0)
PY
)

[ -z "$FINDING" ] && exit 0

length=${FINDING%%$'\t'*}
excerpt=${FINDING#*$'\t'}
echo "commit-message-wrap-guard: blocked. A commit message body line runs $length characters, over the $LIMIT the commit message guide sets: \"$excerpt…\". \`git commit -m\` does not wrap, so it would land as one long line. Write the message to a file with the Write tool and commit with \`git commit -F <file>\`, or break the body lines yourself inside the -m string." >&2
exit 2
