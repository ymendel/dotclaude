#!/usr/bin/env python3
"""PermissionRequest hook: approves read-only git run against another directory with `git -C <dir>`.

No allow rule can cover that form. A Bash rule has to start with the command name, and a `*` in
place of the directory would also match `git -C <dir> -c <config> …`, where config can name a
program to run. So this parses the command and approves only one exact shape:

    [rtk] git -C <dir> <grep|show|log|ls-tree|ls-files> <args…>

as a single command with no expansion, refusing the options that run a program or write a file.
The `rtk` prefix is accepted because RTK rewrites `git -C` into that form and leaves it to prompt.

Out of scope: config already present in the target repo's own `.git/config` (an fsmonitor, a
textconv driver) runs whatever reads that repo, this hook or not. The global `git grep:*` allow rule
carries the same exposure.

Approves or abstains, never denies. Checks live in hooks/test/run-git-read-allow.sh.
"""

import datetime
import json
import os
import shlex
import sys

SUBCOMMANDS = {"grep", "show", "log", "ls-tree", "ls-files"}

# Characters that make the shell do more than run one command. `$` and backticks expand even inside
# double quotes, which shlex treats as literal text, so they are refused anywhere in the string.
UNSAFE_CHARS = set("$`\n\r")

# shlex's default operator set. A token made only of these is an operator rather than a word.
OPERATOR_CHARS = set("();<>|&")

LOG = os.environ.get("CLAUDE_GIT_READ_LOG", os.path.expanduser("~/.claude/.git-read-allow.log"))


def log_decision(reason, command):
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = " ".join(command.split())[:200] if command else "-"
    try:
        with open(LOG, "a") as log_file:
            log_file.write(f"{timestamp} {reason} {line}\n")
    except OSError:
        pass


def long_option_name(token):
    return token[2:].split("=", 1)[0]


def runs_pager(token):
    """grep's -O / --open-files-in-pager, including bundled short flags and abbreviations."""
    if token.startswith("--"):
        # git accepts any unambiguous prefix of a long option. `--or` is a real grep option and
        # does not start with "op".
        return long_option_name(token).startswith("op")
    return token.startswith("-") and "O" in token[1:]


def writes_output(token):
    """log/show's --output=<file>, including abbreviations."""
    return token.startswith("--") and long_option_name(token).startswith("ou")


def decide(command):
    if any(char in UNSAFE_CHARS for char in command):
        return "unsafe-char"

    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        return "unparsed-command"

    if any(token and set(token) <= OPERATOR_CHARS for token in tokens):
        return "compound"

    if tokens[:1] == ["rtk"]:
        tokens = tokens[1:]

    if len(tokens) < 4 or tokens[0] != "git" or tokens[1] != "-C":
        return "shape"

    subcommand, arguments = tokens[3], tokens[4:]
    if subcommand.startswith("-"):
        return "global-option"
    if subcommand not in SUBCOMMANDS:
        return "subcommand"

    for argument in arguments:
        if subcommand == "grep" and runs_pager(argument):
            return "pager"
        if subcommand in ("log", "show") and writes_output(argument):
            return "output"

    return "allow"


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        log_decision("unparsed", "")
        return

    if payload.get("tool_name") != "Bash":
        log_decision("wrong-tool", "")
        return

    command = (payload.get("tool_input") or {}).get("command") or ""
    reason = decide(command)
    log_decision(reason, command)

    if reason == "allow":
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PermissionRequest",
                "decision": {"behavior": "allow"},
            }
        }))


if __name__ == "__main__":
    main()
